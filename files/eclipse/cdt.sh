#!/bin/sh

/opt/eclipse/eclipse -nosplash \
    -application org.eclipse.equinox.p2.director \
    -repository http://download.eclipse.org/tools/cdt/releases/9.0/,http://download.eclipse.org/releases/neon/ \
    -destination /opt/eclipse \
    -installIU org.eclipse.cdt.feature.group \
    -installIU org.eclipse.cdt.platform.feature.group | grep -v DEBUG
