# EXOFASTv2 -- Jason Eastman (jason.eastman@cfa.harvard.edu)
# An exoplanet transit and radial velocity fitting software package in IDL
# If you use this in a publication, please cite:
# http://adsabs.harvard.edu/abs/2017ascl.soft10003E

### INSTALLATION INSTRUCTIONS ### 

# Note the IDL Astronomy library is required. If you don't already
# have it, install it from here: https://github.com/wlandsman/IDLAstro

# This package is best installed with git
cd $HOME/idl
git clone https://github.com/jdeast/EXOFASTv2.git

# define environment variables (bash shell, e.g., .bashrc)
# EXOFAST_PATH="$HOME/idl/EXOFASTv2/" ; export EXOFAST_PATH
# IDL_PATH="$IDL_PATH:+$EXOFAST_PATH" ; export IDL_PATH
#
#--- OR ---
#
# define environment variables (c shell, e.g., .tcshrc)
# setenv EXOFAST_PATH "${HOME}/idl/EXOFASTv2/"
# setenv IDL_PATH "${IDL_PATH}:+${EXOFAST_PATH}"

# If you have used the old version of EXOFAST, you must remove it from
# your IDL_PATH to run correctly.

# to test your installation, try the HAT-3b example:
cd $EXOFAST_PATH/examples/hat3
idl -e "fithat3"

# TIP: make your terminal wide so the MCMC updates don't spam the screen

# this should complete in a couple minutes and generate several 
# output files (HAT-P-3b.*). If it does not compile or fails, check for missing 
# dependencies (e.g., IDL astronomy library)

# to get future updates
cd $EXOFAST_PATH
git pull

#### TIPS, WARNINGS and CAVEATS #####

# EXOFASTv2 has been built and tested on linux with IDL 8.5, though I
# am not aware of any incompatibility for other versions or
# platforms. The original EXOFAST has been used successfully with v6.4
# and with Mac and Windows. It is my hope to support as many versions
# as reasonable, so if you have version related bugs, please let me
# know. This code relies heavily on pointers and structures, so
# versions older than IDL 5.0 will never be supported.

# other examples are available for various use cases, which are
# intended to be templates for your own fits, including running
# EXOFASTv2 without an IDL license. 
# See $EXOFAST_PATH/examples/README for more information.

# This is a BETA version. EXPECT BUGS!!! And please report any
# unexpected behavior.

# It is not fully documented. Please don't hesitate to email me with
# questions. See the $EXOFAST_PATH/examples directory for templates to
# get started on your own fits.

# Major releases or bug fixes will be announced on twitter
# (@exofastupdates)


