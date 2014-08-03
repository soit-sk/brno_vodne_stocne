#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use URI;

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://www.bvk.cz/zakaznikum/cenik/');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get base root.
print 'Page: '.$base_uri->as_string."\n";
my $root = get_root($base_uri);

# Process table.
my $table = $root->find_by_tag_name('table');
my @tr = $table->find_by_tag_name('tr');
shift @tr;
shift @tr;
foreach my $tr (@tr) {
	my @td = $tr->find_by_tag_name('td');
	my ($year, $celkem, $vodne, $stocne) = map { 
		my $value = $td[$_]->as_text;
		remove_trailing(\$value);
		$value =~ s/,/\./ms;
		$value;
	} (0 .. 3);

	# Save.
	my $ret_ar = eval {
		$dt->execute('SELECT COUNT(*) FROM data WHERE Rok = ?',
			$year);
	};
	if ($EVAL_ERROR || ! @{$ret_ar} || ! exists $ret_ar->[0]->{'count(*)'}
		|| ! defined $ret_ar->[0]->{'count(*)'}
		|| $ret_ar->[0]->{'count(*)'} == 0) {

		print "Year: $year\n";
		$dt->insert({
			'Rok' => $year,
			'Celkem' => $celkem,
			'Vodne' => $vodne,
			'Stocne' => $stocne,
		});
	}
}

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Removing trailing whitespace.
sub remove_trailing {
	my $string_sr = shift;
	${$string_sr} =~ s/^\s*//ms;
	${$string_sr} =~ s/\s*$//ms;
	return;
}
