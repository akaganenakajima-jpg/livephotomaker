const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Exclude the archived Swift scaffold from Metro's watch tree.
config.resolver.blockList = [
  /_legacy-swift\/.*/,
];

module.exports = config;
