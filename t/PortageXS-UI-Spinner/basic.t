use strict;
use warnings;

use Test::More;
use Test::Output;
use Test::Fatal;

sub nofatal {
    my ( $message, $sub ) = @_;
    my $e = exception { $sub->() };
    return is( $e, undef, $message );
}

subtest 'STDOUT based interface' => sub {
    return unless nofatal 'Can load PortageXS::UI::Spinner' => sub {
        require PortageXS::UI::Spinner;
    };
    my $instance;
    return unless nofatal 'Create an instance' => sub {
        $instance = PortageXS::UI::Spinner->new();
    };
    return unless nofatal "Spin a few times" => sub {
        stdout_is(
            sub {
                $instance->spin for 1 .. 8;
            },
            "\b/\b-\b\\\b|\b/\b-\b\\\b|",
            "spin outputs expectedly"
        );
    };
};

subtest 'Handle based interface' => sub {
    return unless nofatal 'Can load PortageXS::UI::Spinner' => sub {
        require PortageXS::UI::Spinner;
    };
    my $instance;
    my $output = q{};
    open my $output_writer, '>', \$output
      or die "IO On strings not supported, $? $! $@";
    return unless nofatal 'Create an instance' => sub {
        $instance =
          PortageXS::UI::Spinner->new( output_handle => $output_writer, );
    };
    return unless nofatal "Spin a few times" => sub {
        stdout_is(
            sub {
                $instance->spin for 1 .. 8;
            },
            "",
            "spin outputs nothing to STDOUT"
        );
        is( $output, "\b/\b-\b\\\b|\b/\b-\b\\\b|",
            "written string outputs expectedly" );
    };
};

done_testing;
