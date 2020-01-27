#!/bin/sh

PROJECT_ROOT=$(cd $(dirname ${BASH_SOURCE[0]})/../ && pwd)

if [ ! -d ${PROJECT_ROOT}/Modules/BRCore/breadwallet-core ]; then
    git clone https://github.com/breadwallet/breadwallet-core.git ${PROJECT_ROOT}/Modules/BRCore/breadwallet-core &&
    git -C ${PROJECT_ROOT}/Modules/BRCore/breadwallet-core checkout ca9a6bdda547223824cb22f885a2edf0eb6a21e3 &&
    git -C ${PROJECT_ROOT}/Modules/BRCore/breadwallet-core submodule init &&
    git -C ${PROJECT_ROOT}/Modules/BRCore/breadwallet-core submodule update
fi

cp -a ${PROJECT_ROOT}/Modules/BRCore/patches/* ${PROJECT_ROOT}/Modules/BRCore/breadwallet-core/

