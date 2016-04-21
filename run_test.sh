#!/bin/bash

# Adapted from Twinkles cookbook
# https://github.com/DarkEnergyScienceCollaboration/Twinkles/blob/master/doc/Cookbook/twinkles_cookbook.md

OUTPUT=output_data_small
gVISITS=840^841
rVISITS=860^861
iVISITS=870^871
VISITS=${gVISITS}^${rVISITS}^${iVISITS}
FILTERS=g^r^i

# Setup the reference catalog for photometric and astrometric calibration
setup -m none -r ${TESTDATA_LSSTSIM_DIR}/and_files astrometry_net_data

# Create calibrated images from the input eimages.  
# The --id argument # defines the data to operate on.  
# In this case it means process all data from visits 840, 841, 860, 861, 870, 871
# The argument parsing uses '^' as the separator character for unfortunate historical reasons
processEimage.py input_data --id visit=${VISITS} --output ${OUTPUT}

# Make a skyMap to use as the basis for the astrometic system for the coadds.  This can't be done up front because
# makeDiscreteSkyMap decides how to build the patches and tracts for the skyMap based on the data.
makeDiscreteSkyMap.py ${OUTPUT} --id visit=${VISITS} --output ${OUTPUT}

# Coadds are done in two steps.  Step one is to warp the data to a common astrometric system.  The following does that.
# The config option is to use background subtracted exposures as inputs.  You can also specify visits using the ^ operator meaning 
# 'and'.
makeCoaddTempExp.py ${OUTPUT} --selectId visit=${gVISITS} --id filter=r patch=0,0 tract=0 --config bgSubtracted=True --output ${OUTPUT}
makeCoaddTempExp.py ${OUTPUT} --selectId visit=${rVISITS} --id filter=g patch=0,0 tract=0 --config bgSubtracted=True --output ${OUTPUT}
makeCoaddTempExp.py ${OUTPUT} --selectId visit=${iVISITS} --id filter=i patch=0,0 tract=0 --config bgSubtracted=True --output ${OUTPUT}

# This is the second step which actually coadds the warped images.  The doInterp config option is required if there
# are any NaNs in the image (which there will be for this set since the images do not cover the whole patch).
assembleCoadd.py ${OUTPUT} --selectId visit=${gVISITS} --id filter=r patch=0,0 tract=0 --config doInterp=True --output ${OUTPUT}
assembleCoadd.py ${OUTPUT} --selectId visit=${rVISITS} --id filter=g patch=0,0 tract=0 --config doInterp=True --output ${OUTPUT}
assembleCoadd.py ${OUTPUT} --selectId visit=${iVISITS} --id filter=i patch=0,0 tract=0 --config doInterp=True --output ${OUTPUT}

# Detect sources in the coadd and then merge detections from multiple bands.
detectCoaddSources.py ${OUTPUT} --id tract=0 patch=0,0 filter=${FILTERS} --output ${OUTPUT}
mergeCoaddDetections.py ${OUTPUT} --id tract=0 patch=0,0 filter=${FILTERS} --output ${OUTPUT}

# Do measurement on the sources detected in the above steps and merge the measurements from multiple bands.
measureCoaddSources.py ${OUTPUT} --id tract=0 patch=0,0 filter=${FILTERS} --config measurement.doApplyApCorr=yes --output ${OUTPUT}
mergeCoaddMeasurements.py ${OUTPUT} --id tract=0 patch=0,0 filter=${FILTERS} --output ${OUTPUT}

# Use the detections from the coadd to do forced photometry on all the single frame data.
forcedPhotCcd.py ${OUTPUT} --id tract=0 visit=${VISITS} sensor=1,1 raft=2,2 --config measurement.doApplyApCorr=yes --output ${OUTPUT}
