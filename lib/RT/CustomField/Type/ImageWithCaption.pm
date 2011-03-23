package RT::CustomField::Type::ImageWithCaption;
use strict;
use warnings;

sub CanonicalizeForCreate {
    my ($self, $cf, $args) = @_;

    return wantarray ? (1) : 1;
}

sub Stringify {
    my ($self, $ocfv) = @_;
    my $content = $ocfv->_Value('Content');

    return $content
}

sub CreateArgsFromWebArgs {
    my ($self, $cf, $web_args) = @_;

    my $args = HTML::Mason::Commands::_UploadedFileArgs($web_args->{Upload});
    $args->{Value} = $web_args->{Value}; # override value over filename from upload
    return $args;
}

1;
