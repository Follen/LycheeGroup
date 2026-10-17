// Build the shareable, offline prototype. Source pages reuse the v3 game artwork.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = __dirname;
const assetRoot = path.join(root, '..', 'prototype-v3', 'assets');
const mime = {'.png':'image/png', '.jpg':'image/jpeg', '.ogg':'audio/ogg'};
const assetFiles = [
  ...fs.readdirSync(assetRoot).filter(file => mime[path.extname(file)]),
  ...['search','plus','book','mountain','tower','delve','pvp','flag','chevron','close','refresh','heart','caution','friend','guild','bell','history','arrow',
      'leader','role-tank-silver','role-healer-flat','role-dps-flat'].map(name => 'icons/'+name+'.png'),
  'wow/classes.png', 'wow/evoker.jpg', 'sounds/native-application.ogg'
];
const assets = Object.fromEntries(assetFiles.map(file => [file,
  'data:' + mime[path.extname(file)] + ';base64,' + fs.readFileSync(path.join(assetRoot,file)).toString('base64')
]));
let html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
html = html.replace(/<link rel="stylesheet" href="([^"]+)">/g, (_, file) =>
  '<style>\n' + fs.readFileSync(path.join(root,file),'utf8') + '\n</style>');
html = html.replace('../prototype-v3/assets/lychee-logo.png', assets['lychee-logo.png']);
html = html.replace(/<script src="([^"]+)"><\/script>/g, (_, file) => {
  let code = fs.readFileSync(path.join(root,file),'utf8');
  if (file === 'app.js') {
    code = 'const EMBEDDED_ASSETS=' + JSON.stringify(assets) + ';\n' +
      code.replace("const assetSrc = path => '../prototype-v3/assets/'+path;", 'const assetSrc = path => EMBEDDED_ASSETS[path];');
  }
  new vm.Script(code, {filename:file});
  return '<script>\n' + code.replace(/<\/script/gi, '<\\/script') + '\n</script>';
});
const output = path.join(root,'荔枝组队-v4.html');
fs.writeFileSync(output, html);
console.log(path.basename(output) + ' · ' + assetFiles.length + ' embedded assets · ' + (Buffer.byteLength(html)/1024/1024).toFixed(2) + ' MiB');
