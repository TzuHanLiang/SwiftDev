#!/bin/sh

PROJECT_ROOT=$(cd $(dirname ${BASH_SOURCE[0]})/../ && pwd)

CARTHAGE_ACTION=$(if [ -e ${PROJECT_ROOT}/Cartfile.resolved ]; then echo bootstrap; else echo update; fi)

PLATFORM=$1
if [ ${PLATFORM} == macOS ]; then
    PLATFORM=Mac
fi

print_usage() {
    echo "Usage:\n\t$0 < iOS | macOS >\n"
}

build_CoreStore() {
    if [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/CoreStore.framework ] || [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/CoreStore.framework.dSYM ]; then
        echo "Build CoreStore.framework"
        cd ${PROJECT_ROOT} && carthage update CoreStore --platform ${PLATFORM}
    fi
}

build_CryptoSwift() {
    if [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/CryptoSwift.framework ] || [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/CryptoSwift.framework.dSYM ]; then
        echo "Build CryptoSwift.framework"
        cd ${PROJECT_ROOT} && carthage update CryptoSwift --platform ${PLATFORM}
    fi
}

build_CryptoEthereumSwift() {
    if [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/CryptoEthereumSwift.framework ] || [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/CryptoEthereumSwift.framework.dSYM ]; then
        echo "Build CryptoEthereumSwift.framework"
        cd ${PROJECT_ROOT} && carthage update CryptoEthereumSwift --platform ${PLATFORM}
    fi
}

build_EthereumKit() {
    if [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/EthereumKit.framework ] || [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/EthereumKit.framework.dSYM ]; then
        echo "Build EthereumKit.framework"
        cd ${PROJECT_ROOT} && carthage update EthereumKit --platform ${PLATFORM}
    fi
}

build_Ed25519Swift() {
    if [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/Ed25519Swift.framework ] || [ ! -e ${PROJECT_ROOT}/Carthage/Build/${PLATFORM}/Ed25519Swift.framework.dSYM ]; then
        echo "Build Ed25519Swift.framework"
        cd ${PROJECT_ROOT} && carthage update Ed25519Swift --platform ${PLATFORM}
    fi
}

if [ $# != 1 ]; then
    print_usage
    exit 1
fi

if [ ${PLATFORM} != iOS ] && [ ${PLATFORM} != Mac ]; then
    print_usage
    exit 1
fi

if [ ! -e ${PROJECT_ROOT}/Cartfile ]; then
    echo "Cartfile not found!"
    exit 1
fi

build_CoreStore
build_Ed25519Swift
build_EthereumKit
build_CryptoEthereumSwift
build_CryptoSwift

