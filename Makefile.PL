use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'      => 'PHP::Session',
    'VERSION_FROM' => 'lib/PHP/Session.pm', # finds $VERSION
    'PREREQ_PM' => {
	Test::More => 0.32,
	Text::Balanced => 1.89,
	UNIVERSAL::require => 0.03,
    },
);
