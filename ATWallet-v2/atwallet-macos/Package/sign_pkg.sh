#!/bin/sh

productsign --sign "Developer ID Installer: AuthenTrend Technology Inc." build/AT.Wallet.pkg build/AT.Wallet.signed.pkg
productsign --sign "Developer ID Installer: AuthenTrend Technology Inc." build/AT.Wallet\ Testnet.pkg build/AT.Wallet_Testnet.signed.pkg

