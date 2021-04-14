const path = require('path');

module.exports = {
  entry: './src/index.js',
  mode: 'none',
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'dist'),
  },
  watch: true,
  watchOptions: {
    ignored: /node_modules/
  },
  module: {
    rules: [{
      test: /\.css$/i,
      use: ['style-loader', 'css-loader'],
    }],
  },
};
