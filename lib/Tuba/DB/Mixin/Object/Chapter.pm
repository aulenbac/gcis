package Tuba::DB::Object::Chapter;
# Tuba::DB::Mixin::Object::Chapter;

sub uri {
    my $s = shift;
    my $c = shift;
    return $c->url_for(
        'show_chapter',
        {
            chapter_identifier => $s->identifier,
            report_identifier  => $s->report_obj->identifier
        }
    );
}

sub stringify {
    my $s = shift;
    return $s->title unless $s->number;
    return "Chapter ".$s->number." : ".$s->title;
}

1;
