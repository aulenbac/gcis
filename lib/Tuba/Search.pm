package Tuba::Search;

use Tuba::DB::Objects qw/-nicknames/;
use Mojo::Base qw/Tuba::Controller/;
use List::MoreUtils qw/mesh/;
use Tuba::Log;
use strict;

sub keyword {
    my $c = shift;
    my $q = $c->param('q') or return $c->render(results => [], result_count_text => 'Please enter search terms');

    my $orm = $c->orm;
    my @tables = keys %$orm;
    my $type = $c->param('type');
    @tables = ( $type ) if $type && exists($orm->{$type});
    my @results;
    my $result_count_text;
    my $hit_max = 0;
    for my $table (@tables) {
        next if $table eq 'publication';
        my $manager = $orm->{$table}->{mng};
        next unless $manager->has_urls($c);
        my @these = $manager->dbgrep(query_string => $q, user => $c->user, limit => (@tables > 1 ? 10 : 50));
        $hit_max = 1 if @these==10 && @tables > 1;
        push @results, @these;
    }

    $result_count_text = scalar @results;
    if (@tables == 1 && $result_count_text == 50) {
        $result_count_text = "more than 50 results.  Only showing the first 50.";
    } else {
        $result_count_text = "$result_count_text result";
        $result_count_text .= 's' unless @results==1;
        $result_count_text .= '.';
        $result_count_text .= "  Only the first 10 results of each type are shown. ".
            "To see more, chose a type in the form above." if $hit_max;

    }
    $c->stash(result_count_text => $result_count_text);
    $c->respond_to(
        any => sub { shift->render(results => \@results); },
        json => sub { my $c = shift; $c->render(json => [ map $_->as_tree(c => $c, bonsai => 1), @results ]); },
        yaml => sub { my $c = shift; $c->render_yaml([ map $_->as_tree(c => $c, bonsai => 1), @results ]); },
    );
}

sub autocomplete {
    my $c = shift;
    my $q = $c->param('q') || $c->json->{q};
    return $c->render(json => []) unless $q && length($q) >= 1;
    my $max = $c->param('items') || 20;
    my $want = $c->param('type') || 'all';  # all == all publications, full = orgs, people too
    my $elide = $c->param('elide') || 80;
    my $gcids = $c->param('gcids');
    my $restrict = $c->param('restrict');

    my @tables;
    if ($want && $want=~/^(array|finding|table|journal|region|gcmd_keyword|person|organization|reference|file|activity|dataset|figure|image|report|chapter|article|webpage|book|generic|platform|instrument)$/) {
       @tables = ( $want );
    } elsif ($want && ($want !~ /^(all|full)$/)) {
        return $c->render(json => { error => "undefined type" } );
    } elsif ($want eq 'all') {
       @tables = map $_->table, @{ PublicationTypes->get_objects(all => 1) };
    } elsif ($want eq 'full') {
       @tables = map $_->table, @{ PublicationTypes->get_objects(all => 1) };
       push @tables, ('organization', 'person');
    }
    my @results;
    for my $table (@tables) {
        next if $want && $want !~ /^(all|full)$/ && $table ne $want;
        my $manager = $c->orm->{$table}{mng} or die "no manager for $table";
        my @got = $manager->dbgrep(query_string => $q, limit => $max, user => $c->user, restrict => $restrict);
        for (@got) {
            if ($gcids) {
                push @results, $_->as_gcid_str($c,$elide,$table);
            } else {
                push @results, $_->as_autocomplete_str($elide,$table);
            }
        }
    }

    return $c->render(json => \@results );
}

sub autocomplete_str_to_object {
    # Reverse the above.
    my $c = shift;
    my $str = shift;
    my ($type) =
        $str =~ /^ \[
                       ( [^]]+ )
                   \]
                  /x;
    return unless $type;
    my $class = $c->orm->{$type}->{obj} or die "no class for $type";
    return $class->new_from_autocomplete($str);
}

sub gcid {
    my $c = shift;
    $c->render(template => "search/gcid");
}


1;
