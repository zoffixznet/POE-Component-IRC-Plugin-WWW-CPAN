#!/usr/bin/env perl

use Test::More tests => 3;

BEGIN {
    use_ok('POE::Component::IRC::Plugin::BasePoCoWrap');
    use_ok('POE::Component::WWW::CPAN');
	use_ok( 'POE::Component::IRC::Plugin::WWW::CPAN' );
}

diag( "Testing POE::Component::IRC::Plugin::WWW::CPAN $POE::Component::IRC::Plugin::WWW::CPAN::VERSION, Perl $], $^X" );
