# Makefile for gnofract4d conversion using reposurgeon
#
# Steps to using this:
# 1. Make sure reposurgeon and repotool are on your $PATH.
# 2. (Skip this step if you're starting from a stream file.) For svn, set
#    REMOTE_URL to point at the remote repository you want to convert.
#    If the repository is already in a DVCS such as hg or git,
#    set REMOTE_URL to either the normal cloning URL (starting with hg://,
#    git://, etc.) or to the path of a local clone.
# 3. For cvs, set CVS_HOST to the repo hostname and CVS_MODULE to the module,
#    then uncomment the line that builds REMOTE_URL 
#    Note: for CVS hosts other than Sourceforge or Savannah you will need to 
#    include the path to the CVS modules directory after the hostname.
# 4. Set any required read options, such as --user-ignores or --nobranch,
#    by setting READ_OPTIONS.
# 5. Optionally, replace the default value of DUMPFILTER with a
#    command or pipeline that actually filters the dump rather than
#    just copying it through.  The most usual reason to do this is
#    that your Subversion repository is multiproject and you want to
#    strip out one subtree for conversion with repocutter sift and pop
#    commands.  Note that if you ever did copies across project
#    subtrees this simple stripout will not work - you are in deep
#    trouble and should find an expert to advise you
# 6. Run 'make stubmap' to create a stub author map.
# 7. Run 'make' to build a converted repository.
#
# The reason both first- and second-stage stream files are generated is that,
# especially with Subversion, making the first-stage stream file is often
# painfully slow. By splitting the process, we lower the overhead of
# experiments with the lift script.
#
# For a production-quality conversion you will need to edit the map
# file and the lift script.  During the process you can set EXTRAS to
# name extra metadata such as a comments message-box.
#
# Afterwards, you can use the headcompare and tagscompare productions
# to check your work.
#

EXTRAS = 
REMOTE_URL = svn://svn.debian.org/gnofract4d
#REMOTE_URL = https://gnofract4d.googlecode.com/svn/
CVS_HOST = gnofract4d.cvs.sourceforge.net
#CVS_HOST = cvs.savannah.gnu.org
CVS_MODULE = gnofract4d
#REMOTE_URL = cvs://$(CVS_HOST)/gnofract4d\#$(CVS_MODULE)
READ_OPTIONS =
DUMPFILTER = cat
VERBOSITY = "set progress"
REPOSURGEON = reposurgeon
LOGFILE = conversion.log

# Configuration ends here

.PHONY: local-clobber remote-clobber gitk gc compare clean dist stubmap
# Tell make not to auto-remove tag directories, because it only tries rm 
# and hence fails
.PRECIOUS: gnofract4d-%-checkout gnofract4d-%-git

default: gnofract4d-git

# Build the converted repo from the second-stage fast-import stream
gnofract4d-git: gnofract4d.fi
	rm -fr gnofract4d-git; $(REPOSURGEON) $(VERBOSITY) 'read <gnofract4d.fi' 'prefer git' 'rebuild gnofract4d-git'

# Build the second-stage fast-import stream from the first-stage stream dump
gnofract4d.fi: gnofract4d.cvs gnofract4d.opts gnofract4d.lift gnofract4d.map $(EXTRAS)
	$(REPOSURGEON) $(VERBOSITY) 'logfile $(LOGFILE)' 'script gnofract4d.opts' "read $(READ_OPTIONS) <gnofract4d.cvs" 'authors read <gnofract4d.map' 'sourcetype cvs' 'prefer git' 'script gnofract4d.lift' 'legacy write >gnofract4d.fo' 'write >gnofract4d.fi'

# Build the first-stage stream dump from the local mirror
gnofract4d.cvs: gnofract4d-mirror
	(cd gnofract4d-mirror/ >/dev/null; repotool export) | $(DUMPFILTER) >gnofract4d.cvs

# Build a local mirror of the remote repository
gnofract4d-mirror:
	#repotool mirror $(REMOTE_URL) gnofract4d-mirror
	#rsync --archive --recursive --update ../gnofract4d_cvs/ gnofract4d-mirror
	rsync --compress-level=9 --archive --recursive --update --times rsync://a.cvs.sourceforge.net/cvsroot/gnofract4d/\* gnofract4d-mirror/

# Make a local checkout of the source mirror for inspection
gnofract4d-checkout: gnofract4d-mirror
	cd gnofract4d-mirror >/dev/null; repotool checkout $(PWD)/gnofract4d-checkout

# Make a local checkout of the source mirror for inspection at a specific tag
gnofract4d-%-checkout: gnofract4d-mirror
	cd gnofract4d-mirror >/dev/null; repotool checkout $(PWD)/gnofract4d-$*-checkout $*

# Force rebuild of first-stage stream from the local mirror on the next make
local-clobber: clean
	rm -fr gnofract4d.fi gnofract4d-git *~ .rs* gnofract4d-conversion.tar.gz gnofract4d-*-git

# Force full rebuild from the remote repo on the next make.
remote-clobber: local-clobber
	rm -fr gnofract4d.cvs gnofract4d-mirror gnofract4d-checkout gnofract4d-*-checkout

# Get the (empty) state of the author mapping from the first-stage stream
stubmap: gnofract4d.cvs
	$(REPOSURGEON) $(VERBOSITY) "read $(READ_OPTIONS) <gnofract4d.cvs" 'authors write >gnofract4d.map'

# Compare the histories of the unconverted and converted repositories at head
# and all tags.
EXCLUDE = -x CVS -x .cvs -x .git
EXCLUDE += -x .cvsignore -x .gitignore
headcompare: gnofract4d-mirror gnofract4d-git
	repotool compare $(EXCLUDE) gnofract4d-mirror gnofract4d-git
tagscompare: gnofract4d-mirror gnofract4d-git
	repotool compare-tags $(EXCLUDE) gnofract4d-mirror gnofract4d-git
branchescompare: gnofract4d-mirror gnofract4d-git
	repotool compare-branches $(EXCLUDE) gnofract4d-mirror gnofract4d-git
allcompare: gnofract4d-mirror gnofract4d-git
	repotool compare-all $(EXCLUDE) gnofract4d-mirror gnofract4d-git

# General cleanup and utility
clean:
	rm -fr *~ .rs* gnofract4d-conversion.tar.gz *.cvs *.fi *.fo

# Bundle up the conversion metadata for shipping
SOURCES = Makefile gnofract4d.lift gnofract4d.map $(EXTRAS)
gnofract4d-conversion.tar.gz: $(SOURCES)
	tar --dereference --transform 's:^:gnofract4d-conversion/:' -czvf gnofract4d-conversion.tar.gz $(SOURCES)

dist: gnofract4d-conversion.tar.gz

#
# The following productions are git-specific
#

# Browse the generated git repository
gitk: gnofract4d-git
	cd gnofract4d-git; gitk --all

# Run a garbage-collect on the generated git repository.  Import doesn't.
# This repack call is the active part of gc --aggressive.  This call is
# tuned for very large repositories.
gc: gnofract4d-git
	cd gnofract4d-git; time git -c pack.threads=1 repack -AdF --window=1250 --depth=250
