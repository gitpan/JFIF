#!/usr/bin/perl

use JPEG::JFIF;
use strict;

my $jfif = new JPEG::JFIF(filename=>"test.jpg");
my $caption = $jfif->get(2,120); # this give you "caption" from adobe. All formats are described in IPTC-NAA specification.
$jfif->set_comment("this is my new caption");
$jfif->write("out.jpg");
