package JPEG::JFIF;
$JPEG::JFIF::VERSION = '0.8';
use strict;

sub new {
    my ($c, %args) = @_;
    my $class = ref($c) || $c;
    bless \%args, $class;
}

sub get {
    my ($cl,$marker_type_p,$data_set_p) = @_;
    
    my $buffer;
    open(FILE,$cl->{filename}) || die "Can't open file\n";
    binmode(FILE);
    
    read(FILE,$buffer,12);
    if (unpack("n",substr($buffer,0,2)) != 0xffd8) { die "Not JPEG\n"; }

    while ((read(FILE,$buffer,2) || exit()) != 0) {
	my $currentpos = tell(FILE);

	if (unpack("n",substr($buffer,0,2)) == 0x0404) { # int16 - ID

	    # next 2 bytes 0x0000
	    read(FILE,$buffer,2); 
	    
	    if (unpack("n",substr($buffer,0,2)) == 0x0000) {
		
		# int32 - Size
		read(FILE,$buffer,4); 
		my $size = unpack("N",substr($buffer,0,4));
		
		my $start = tell(FILE);
		for (my $i = 0; $i<$size;$i++) {
		    seek(FILE,$start + $i,0);
		    read(FILE,$buffer,1);
		    my $c = unpack("C",$buffer);
		    $i += 1; 
		    
		    seek(FILE,$start + $i,0);
		    read(FILE,$buffer,1);
		    my $marker_type = unpack("C",$buffer);

		    if (($c == 0x1C)) {
			$i += 1; 

			seek(FILE,$start + $i,0);
			read(FILE,$buffer,1);
			my $data_set = unpack("C1",$buffer);
			++$i;
			
			seek(FILE,$start + $i,0);
			read(FILE,$buffer,2);
			my $octet_count = unpack("n",$buffer);
			$i += 2;
			
			if ((($data_set == $data_set_p) && ($marker_type == $marker_type_p))) {
			    seek(FILE,$start + $i,0);
			    $cl->{lastgetpos} = tell(FILE);
			    read(FILE,$buffer,$octet_count);
			    $cl->{lastgetposafter} = tell(FILE);
			    close(FILE);
			    return $buffer;
			}
			$i += $octet_count;
		    }
		    $start--;
		}
	    }
	}
    }
}

sub get_raw {
    my ($cl,$what) = @_;
    my ($JPEGSTD,$JFIF,$SOS,$RAWIMAGE,$buffer,$HEADER,$ICCPROFILE,$ICCPROFILERAW) = {0,0,0,0,0,0,0,0};
    open(FILE,$cl->{filename});
    binmode(FILE);

    read(FILE,$buffer, 4);
    if (unpack("N",$buffer) == 0xFFD8FFE0) { $JPEGSTD = 1; }

    seek(FILE,6,0);
    read(FILE,$buffer,4);
    if (unpack("N",$buffer) == 0x4A464946) { $JFIF = 1;  } 

    seek(FILE,0,0);
    while ((read(FILE,$buffer,2) != 0) && ($SOS == 0) || ($ICCPROFILE == 0)) { 
    if (unpack("n",$buffer) == 0xFFDA) {
	$SOS = tell(FILE)-2;
	}

    if (unpack("n",$buffer) == 0xFFE2) {
	$ICCPROFILE = tell(FILE)-2;
	}

    seek(FILE,tell(FILE)-1,0);
    }

    #IMAGE
    if ($what eq "RAWIMAGE"){
	seek(FILE,$SOS,0);
	while (read(FILE,$buffer,1024) != 0) { $RAWIMAGE.=$buffer; }
	close(FILE);
	return $RAWIMAGE;
     }

    #HEADER
    if ($what eq "HEADER") {
	seek(FILE,0,0);
	read(FILE,$HEADER,$ICCPROFILE);
	close(FILE);
	return $HEADER;
    }
    

    #ICCPROFILERAW
    if ($what eq "ICCPROFILE") {
	seek(FILE,$ICCPROFILE,0);
	while (read(FILE,$buffer,1024) != 0) { $ICCPROFILERAW.=$buffer; }
	close(FILE);
	return $ICCPROFILERAW;
    }
    
}

sub set_comment {
    my ($cl,$new) = @_;
    my $old = $cl->get(2,120);
    my $header = $cl->get_raw("HEADER");
    my $buffer;
    
    #zmieniam dlugosc    
    # 22 to jest 0xFFED - zmienic na znalezienie i zamiane po tym, a nie tak na sztywno
    my $len = unpack("n",substr($header,22,2));
    $len = $len - length($old) + length($new);
    substr($header,22,2) = pack("n",$len);

    my $newheader = substr($header,0,$cl->{lastgetpos}-2).pack("n",length($new)).$new.substr($header,$cl->{lastgetposafter});
    $cl->{header} = $newheader;
    return $newheader;
}

sub write {
    my ($cl,$filename) = @_;
    open(FILEOUT,">".$filename) || die "Can't create $filename\n";
    binmode(FILEOUT);
    print FILEOUT $cl->{header};
    print FILEOUT $cl->get_raw("ICCPROFILE");
    close(FILEOUT);
}

1;

__END__

=head1 NAME

JPEG::JFIF - JFIF/JPEG tags operations.

=head1 VERSION

JFIF.pm v 0.8

=head1 CHANGES

 0.8 - can set comment (Caption) tag correctly (hihi)
 0.7 - can read all metatags

=head1 DESCRIPTION

This module can read and set additional info that is set by Adobe Photoshop in jpeg files (JFIF/JPEG format)

=head1 EXAMPLE

    use JPEG::JFIF;
    use strict;

    my $jfif = new JPEG::JFIF(filename=>"test.jpg");

    my $caption = $jfif->get(2,120); # this give you "caption" from adobe. All formats are described in IPTC-NAA specification.

    $jfif->set_comment("this is my new caption");

    $jfif->write("out.jpg");

=head1 COPYRIGHT

Copyright 2002 Marcin Krzyzanowski

=head1 AUTHOR

Marcin Krzyzanowski <krzak at linux.net.pl>
http://krzak.linux.net.pl

=cut