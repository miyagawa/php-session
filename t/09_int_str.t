use strict;
use Test::More tests => 1;

use lib 't/lib';
use TestUtil;

use PHP::Session;

my $sid = "12345";
my $date_str = '20030224000000';

{
    my $session = PHP::Session->new($sid, { create => 1, save_path => 't' });
    $session->set(created => $date_str);
    $session->save();
}

{
    my $session = PHP::Session->new($sid, { save_path => 't' });
    is $session->get('created'), $date_str, "date str is back";
    $session->destroy();
}




