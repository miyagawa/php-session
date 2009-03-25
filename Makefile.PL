use inc::Module::Install;
name 'PHP-Session';
all_from "lib/PHP/Session.pm";
requires 'Test::More';
requires 'UNIVERSAL::require';
auto_set_repository;
auto_include;
WriteAll;
