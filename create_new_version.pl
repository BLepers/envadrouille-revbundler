#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use Cwd;
use JSON;
use File::Basename;

#Compute the diff between the last stable version and previous versions.
#Stables versions are expected to be tagged with a "stable-XXX" tag (XXX = yearmonthday)
#The new version of the files are stored with filenames xxx.ext.last
#The old version of the files are stored with filenames xxx.ext.orig

my $path_to_git = '../envadrouille';
my $current_path = getcwd;
chdir($path_to_git) or die("Directory $path_to_git does not exist\n");



#Create a new stable branch
print `git checkout master`;
my ($sec, $min, $h, $day, $month, $year, @tmp) = localtime();
my $newrev = sprintf("%02d%02d%02d", $year % 100, $month+1, $day);
open(F, "$path_to_git/admin/index.php");
my @indlines = <F>;
close(F);
open(F, "> $path_to_git/admin/index.php");
for my $l (@indlines) {
	if($l =~ /^\$VERSION/) {
		$l = "\$VERSION = '$newrev';\n";
	}
	print F $l;
}
close(F);
my $diff = `git diff`;
if($diff ne '') {
	print "(git commit -a -m 'New revision' && git tag stable-$newrev)\n";
	print `(git commit -a -m 'New revision' && git tag stable-$newrev)\n`;
} else {
	print "No changes to commit bypassing commit and tag creation\n";
}

#Get list of stable revs
my @tags = reverse sort map {
	if($_ =~ m/(stable-\d+)/) {
		$1;
	} else {
		();
	}
} split(/\n/, `git tag`);
print Dumper(\@tags);

#Create diffs for each rev
for my $tag (@tags) {
	next if($tag eq $tags[0]); #Skip the latest tag

	#Get list of changed files. Ignores hidden files (.xxx)
	print "git diff --name-only $tag..master\n";
	my @diff = `git diff --name-only $tag..master`;
	chomp @diff;


	my @json;
	my $patch_dir = "$current_path/envadrouille";
	for my $f (@diff) {
		my $cmd = "mkdir -p $patch_dir/".dirname($f);
		print `$cmd`;
		print `git show $tag:$f > $patch_dir/$f.orig`;
		print `git show master:$f > $patch_dir/$f.last`;
		push(@json, { file => $f, binary => is_binary("$patch_dir/$f.last") });
	}

	open(F, "> $current_path/diff.json");
	print F to_json(\@json);
	close(F);

	chdir($current_path);
	print `zip -r patch-$tag-$tags[0].zip diff.json ./envadrouille`;
	print `rm -rf diff.json ./envadrouille`;
	chdir($path_to_git);

	print "git log $tag..master --pretty=format:'* %s' > $current_path/CHANGELOG-$tag-$tags[0]\n";
	print `git log $tag..master --pretty=format:'* %s' > $current_path/CHANGELOG-$tag-$tags[0]\n`;
	my $changes = `cat $current_path/CHANGELOG-$tag-$tags[0]`;
	open(F, "> $current_path/CHANGELOG-$tag-$tags[0]");
	print F 'showChangelog('.to_json({'changelog' => $changes}).')';
	close(F);
}

print `git checkout master`;
print "git archive --format=zip -o $current_path/envadrouille.zip master\n";
print `(git archive --format=zip -o $current_path/envadrouille.zip master)\n`;

print "(cp $current_path/envadrouille.zip $current_path/latest.zip)\n";
print `(cp $current_path/envadrouille.zip $current_path/latest.zip)`;

chdir($current_path);
open(F, "> VERSION");
my ($revdate) = ($tags[0] =~ m/stable-(\d+)/);
print F "remote_check_version({\"version\":$revdate})";
close(F);

open(F, "> VERSION-JSON");
print F "[\"$revdate\"]";
close(F);

sub is_binary {
	my ($f) = @_;
	my $meta = `file $f`;
	if($meta =~ /text/) {
		return 0;
	} else {
		return 1;
	}
}
