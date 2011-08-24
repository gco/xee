#!/usr/bin/perl

use strict;
use Encode qw(encode decode);

die "Usage: updatestrings.pl translations_file english.strings" unless @ARGV==2;

my %strings=map {
	if(/^\s*"(.*?)(?<!\\)"\s*=\s*"(.*?)(?<!\\)"/)
	{
		($1=>$2);
	}
	else
	{
		();
	}
} read_and_decode($ARGV[0]);

print "\xfe\xff";

for(read_and_decode($ARGV[1]))
{
	if(/^\s*"(.*?)(?<!\\)"\s*=\s*"(.*?)(?<!\\)"/)
	{
		my $translation=($strings{$1} or $1);
		print encode("UTF-16BE","\"$1\" = \"$translation\";\n");
	}
	else
	{
		print encode("UTF-16BE","$_\n");
	}
}

sub read_and_decode($)
{
	my @file=read_file(shift);
	return (map { decode("UTF-16BE",$_) } @file) if $file[0]=~s/^\xfe\xff//;
	return (map { decode("UTF-16LE",$_) } @file) if $file[0]=~s/^\xff\xfe//;
	return (map { decode("UTF-8",$_) } @file);
}

sub read_file($)
{
	open FILE,(shift) or return undef;
	my @file=map { chomp;$_ } <FILE>;
	close FILE;
	return @file;
}
