package ShinyCMS::Controller::Code;

use Moose;
use MooseX::Types::Moose qw/ Int /;
use namespace::autoclean;

BEGIN { extends 'ShinyCMS::Controller'; }


=head1 NAME

ShinyCMS::Controller::Code

=head1 DESCRIPTION

Controller for ShinyCMS codes.

=cut


has posts_per_page => (
	isa     => Int,
	is      => 'ro',
	default => 10,
);


=head1 METHODS

=cut


=head2 base

Set up path and stash some useful info.

=cut

sub base : Chained( '/base' ) : PathPart( 'code' ) : CaptureArgs( 0 ) {
	my ( $self, $c ) = @_;
	
	# Stash the upload_dir setting
	$c->stash->{ upload_dir } = $c->config->{ upload_dir };
	
	# Stash the name of the controller
	$c->stash->{ controller } = 'Code';
}


=head2 get_posts

Get a page's worth of posts

=cut

sub get_posts {
	my ( $self, $c, $page, $count ) = @_;
	
	$page  ||= 1;
	$count ||= 10;
	
	my @posts = $c->model( 'DB::CodePost' )->search(
		{
			posted   => { '<=' => \'current_timestamp' },
			hidden   => 0,
		},
		{
			order_by => { -desc => 'posted' },
			page     => $page,
			rows     => $count,
		},
	);
	
	my $tagged_posts = ();
	foreach my $post ( @posts ) {
		# Stash the tags
		$post->{ tags } = $self->get_tags( $c, $post->id );
		push @$tagged_posts, $post;
	}
	
	return $tagged_posts;
}


=head2 get_posts_for_year

Get a year's worth of posts, broken down by months (for archive widget)

=cut

sub get_posts_for_year {
	my ( $self, $c, $year ) = @_;
	
	my $year_start = DateTime->new(
		day   => 1,
		month => 1,
		year  => $year,
	);
	my $year_end = DateTime->new(
		day   => 1,
		month => 1,
		year  => $year,
	);
	$year_end = $year_end->add( years => 1 );
	
	my @posts = $c->model( 'DB::CodePost' )->search(
		{
			-and => [
				posted => { '<=' => \'current_timestamp' },
				posted => { '>=' => $year_start->ymd     },
				posted => { '<=' => $year_end->ymd       },
			],
			hidden => 0,
		},
		{
			order_by =>  'posted',
		},
	);
	
	my $tagged_posts = ();
	foreach my $post ( @posts ) {
		# Stash the tags
		$post->{ tags } = $self->get_tags( $c, $post->id );
		push @$tagged_posts, $post;
	}
	
	my $by_months = {};
	foreach my $post ( @$tagged_posts ) {
		my $month = $post->posted->month;
		push @{ $by_months->{ $month } }, $post;
	}
	
	my $months = [];
	foreach my $month ( sort {$a<=>$b} keys %$by_months ) {
		push @$months, $by_months->{ $month };
	}
	
	return $months;
}


=head2 get_post

=cut

sub get_post {
	my ( $self, $c, $post_id ) = @_;
	
	return $c->model( 'DB::CodePost' )->find({
		id => $post_id,
	});
}


=head2 get_tags

Get the tags for a post, or for the whole code if no post specified

=cut

sub get_tags {
	my ( $self, $c, $post_id ) = @_;
	
	if ( $post_id ) {
		my $tagset = $c->model( 'DB::Tagset' )->find({
			resource_id   => $post_id,
			resource_type => 'CodePost',
		});
		return $tagset->tag_list if $tagset;
	}
	else {
		my @tagsets = $c->model( 'DB::Tagset' )->search({
			resource_type => 'CodePost',
		});
		my @taglist;
		foreach my $tagset ( @tagsets ) {
			push @taglist, @{ $tagset->tag_list };
		}
		my %taghash;
		foreach my $tag ( @taglist ) {
			$taghash{ $tag } = 1;
		}
		my @tags = keys %taghash;
		@tags = sort { lc $a cmp lc $b } @tags;
		return \@tags;
	}
	
	return;
}


=head2 get_tagged_posts

Get a page's worth of posts with a particular tag

=cut

sub get_tagged_posts {
	my ( $self, $c, $tag, $page, $count ) = @_;
	
	$page  ||= 1;
	$count ||= 10;
	
	my @tags = $c->model( 'DB::Tag' )->search({
		tag => $tag,
	});
	my @tagsets;
	foreach my $tag1 ( @tags ) {
		push @tagsets, $tag1->tagset,
	}
	my @tagged;
	foreach my $tagset ( @tagsets ) {
		next unless $tagset->resource_type eq 'CodePost';
		push @tagged, $tagset->get_column( 'resource_id' ),
	}
	
	my @posts = $c->model( 'DB::CodePost' )->search(
		{
			id       => { 'in' => \@tagged },
			posted   => { '<=' => \'current_timestamp' },
			hidden => 0,
		},
		{
			order_by => { -desc => 'posted' },
			page     => $page,
			rows     => $count,
		},
	);
	
	my $tagged_posts = ();
	foreach my $post ( @posts ) {
		# Stash the tags
		$post->{ tags } = $self->get_tags( $c, $post->id );
		push @$tagged_posts, $post;
	}
	
	return $tagged_posts;
}


=head2 get_posts_by_author

Get a page's worth of posts by a particular author

=cut

sub get_posts_by_author {
	my ( $self, $c, $username, $page, $count ) = @_;
	
	$page  ||= 1;
	$count ||= 10;
	
	my $author = $c->model( 'DB::User' )->find({
		username => $username,
	});
	
	my @posts = $c->model( 'DB::CodePost' )->search(
		{
			author   => $author->id,
			posted   => { '<=' => \'current_timestamp' },
			hidden => 0,
		},
		{
			order_by => { -desc => 'posted' },
			page     => $page,
			rows     => $count,
		},
	);
	
	my $tagged_posts = ();
	foreach my $post ( @posts ) {
		# Stash the tags
		$post->{ tags } = $self->get_tags( $c, $post->id );
		push @$tagged_posts, $post;
	}
	
	return $tagged_posts;
}


=head2 view_posts

Display a page of code posts.

=cut

sub view_posts : Chained( 'base' ) : PathPart( 'page' ) : OptionalArgs( 2 ) {
	my ( $self, $c, $page, $count ) = @_;
	
	$page  ||= 1;
	$count ||= $self->posts_per_page;
	
	my $posts = $self->get_posts( $c, $page, $count );
	
	$c->stash->{ code_posts     } = $posts;
	$c->stash->{ page_num       } = $page;
	$c->stash->{ post_count     } = $count;
	$c->stash->{ posts_per_page } = $self->posts_per_page;
}


=head2 view_recent

Display recent code posts.

=cut

sub view_recent : Chained( 'base' ) : PathPart( '' ) : Args( 0 ) {
	my ( $self, $c ) = @_;
	
	$c->go( 'view_posts' );
}


=head2 view_tag

Display a page of code posts with a particular tag.

=cut

sub view_tag : Chained( 'base' ) : PathPart( 'tag' ) : OptionalArgs( 3 ) {
	my ( $self, $c, $tag, $page, $count ) = @_;
	
	$c->go( 'view_recent' ) unless $tag;
	
	$page  ||= 1;
	$count ||= $self->posts_per_page;
	
	my $posts = $self->get_tagged_posts( $c, $tag, $page, $count );
	
	$c->stash->{ tag        } = $tag;
	$c->stash->{ page_num   } = $page;
	$c->stash->{ post_count } = $count;
	
	$c->stash->{ code_posts } = $posts;
	
	$c->stash->{ template   } = 'code/view_posts.tt';
}


=head2 view_month

Display code posts from a specified month.

=cut

sub view_month : Chained( 'base' ) : PathPart( '' ) : Args( 2 ) {
	my ( $self, $c, $year, $month ) = @_;
	
	my $month_start = DateTime->new(
		day   => 1,
		month => $month,
		year  => $year,
	);
	my $month_end = DateTime->new(
		day   => 1,
		month => $month,
		year  => $year,
	);
	$month_end->add( months => 1 );
	
	my @code_posts = $c->model( 'DB::CodePost' )->search(
		{
			-and => [
				posted => { '<=' => \'current_timestamp' },
				posted => { '>=' => $month_start->ymd    },
				posted => { '<=' => $month_end->ymd      },
			],
			hidden => 0,
		},
		{
			order_by => 'posted',
		},
	);
	
	my $tagged_posts = ();
	foreach my $post ( @code_posts ) {
		# Stash the tags
		$post->{ tags } = $self->get_tags( $c, $post->id );
		push @$tagged_posts, $post;
	}
	$c->stash->{ code_posts } = $tagged_posts;
	
	my $one_month = DateTime::Duration->new( months => 1 );
	my $date = DateTime->new( year => $year, month => $month );
	my $prev = $date - $one_month;
	my $next = $month_end;
	
	$c->stash->{ date      } = $date;
	$c->stash->{ prev      } = $prev;
	$c->stash->{ next      } = $next;
	$c->stash->{ prev_link } = $c->uri_for( $prev->year, $prev->month );
	$c->stash->{ next_link } = $c->uri_for( $next->year, $next->month );
	
	$c->stash->{ template  } = 'code/view_posts.tt';
}


=head2 view_year

Display summary of code posts in a year.

=cut

sub view_year : Chained( 'base' ) : PathPart( '' ) : Args( 1 ) {
	my ( $self, $c, $year ) = @_;
	
	$c->stash->{ months } = $self->get_posts_for_year( $c, $year );
	$c->stash->{ year   } = $year;
}


=head2 view_posts_by_author

Display a page of code posts by a particular author.

=cut

sub view_posts_by_author : Chained( 'base' ) : PathPart( 'author' ) : OptionalArgs( 3 ) {
	my ( $self, $c, $author, $page, $count ) = @_;
	
	$page  ||= 1;
	$count ||= $self->posts_per_page;
	
	my $posts = $self->get_posts_by_author( $c, $author, $page, $count );
	
	$c->stash->{ author     } = $author;
	$c->stash->{ page_num   } = $page;
	$c->stash->{ post_count } = $count;
	
	$c->stash->{ code_posts } = $posts;
	
	$c->stash->{ template   } = 'code/view_posts.tt';
}


=head2 view_post

View a specified code post.

=cut

sub view_post : Chained( 'base' ) : PathPart( '' ) : Args( 3 ) {
	my ( $self, $c, $year, $month, $url_title ) = @_;
	
	my $month_start = DateTime->new(
		day   => 1,
		month => $month,
		year  => $year,
	);
	my $month_end = DateTime->new(
		day   => 1,
		month => $month,
		year  => $year,
	);
	$month_end->add( months => 1 );
	
	# Stash the post
	$c->stash->{ code_post } = $c->model( 'DB::CodePost' )->search({
		url_title => $url_title,
		-and => [
				posted => { '<=' => \'current_timestamp' },
				posted => { '>=' => $month_start->ymd    },
				posted => { '<=' => $month_end->ymd      },
			],
			hidden => 0,
	})->first;
	
	unless ( $c->stash->{ code_post } ) {
		$c->flash->{ error_msg } = 'Failed to find specified code post.';
		$c->go( 'view_recent' );
	}
	
	$c->stash->{ year } = $year;  
	
	# Stash the tags
	$c->stash->{ code_post }->{ tags } = 
		$self->get_tags( $c, $c->stash->{ code_post }->id );
}


=head2 search

Search the code section.

=cut

sub search {
	my ( $self, $c ) = @_;
	
	if ( $c->request->param( 'search' ) ) {
		my $search = $c->request->param( 'search' );
		my $code_posts = [];
		my @results = $c->model( 'DB::CodePost' )->search({
			-and => [
				posted => { '<=' => \'current_timestamp' },
				hidden => 0,
				-or => [
					title => { 'LIKE', '%'.$search.'%'},
					body  => { 'LIKE', '%'.$search.'%'},
				],
			],
		});
		foreach my $result ( @results ) {
			# Pull out the matching search term and its immediate context
			my $match = '';
			if ( $result->title =~ m/(.{0,50}$search.{0,50})/is ) {
				$match = $1;
			}
			elsif ( $result->body =~ m/(.{0,50}$search.{0,50})/is ) {
				$match = $1;
			}
			# Tidy up and mark the truncation
			unless ( $match eq $result->title or $match eq $result->body ) {
				$match =~ s/^\S*\s/... / unless $match =~ m/^$search/i;
				$match =~ s/\s\S*$/ .../ unless $match =~ m/$search$/i;
			}
			if ( $match eq $result->title ) {
				$match = substr $result->body, 0, 100;
				$match =~ s/\s\S+\s?$/ .../;
			}
			# Add the match string to the result
			$result->{ match } = $match;
			
			# Push the result onto the results array
			push @$code_posts, $result;
		}
		$c->stash->{ code_results } = $code_posts;
	}
}



=head1 AUTHOR

Will Braswell <william.braswell@NOSPAM.autoparallel.com>

=head1 COPYRIGHT

NEED ADD COPYRIGHT

=head1 LICENSE

NEED ADD LICENSE

=cut

__PACKAGE__->meta->make_immutable;

1;

