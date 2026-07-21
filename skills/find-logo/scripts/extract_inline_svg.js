// In-page inline-SVG extractor for the find-logo skill.
// Pass to Playwright CLI's `eval` with an element selector as the target:
//   playwright-cli eval "$(cat extract_inline_svg.js)" "<css-selector>" --filename raw.svg
// It returns a cleaned, standalone SVG string (or null if no <svg> is under the target).
// Deliberately uses NO backticks and NO `$` so it survives shell "$(cat ...)" interpolation.
(el) => {
  var svg = (el && el.tagName && el.tagName.toLowerCase() === 'svg') ? el : (el && el.querySelector ? el.querySelector('svg') : null);
  if (!svg) return null;

  var SHAPES = 'path,rect,circle,ellipse,line,polyline,polygon,text,g,use';

  // Inline computed fill/stroke onto shapes that rely on CSS or currentColor, so the SVG survives
  // standalone. Skip shapes that already carry an explicit presentation fill, and skip the SVG
  // default (black) so we do not stamp fills onto everything.
  var live = svg.querySelectorAll(SHAPES);
  for (var i = 0; i < live.length; i++) {
    var o = live[i];
    var cs = getComputedStyle(o);
    ['fill', 'stroke'].forEach(function (prop) {
      var attr = o.getAttribute(prop);
      var val = cs.getPropertyValue(prop);
      if (attr === 'currentColor') {
        o.setAttribute(prop, cs.color || val);
      } else if (!attr && val && val !== 'none' && val !== 'rgb(0, 0, 0)') {
        o.setAttribute(prop, val);
      }
    });
  }

  var clone = svg.cloneNode(true);
  clone.setAttribute('xmlns', 'http://www.w3.org/2000/svg');

  // xmlns:xlink only if some node actually uses an xlink: attribute
  var usesXlink = false;
  var all = clone.querySelectorAll('*');
  for (var j = 0; j < all.length && !usesXlink; j++) {
    var atts = all[j].attributes;
    for (var k = 0; k < atts.length; k++) {
      if (atts[k].name.indexOf('xlink:') === 0) { usesXlink = true; break; }
    }
  }
  if (usesXlink) clone.setAttribute('xmlns:xlink', 'http://www.w3.org/1999/xlink');

  // Ensure a viewBox so the file scales cleanly
  if (!clone.getAttribute('viewBox')) {
    var w = parseFloat(svg.getAttribute('width'));
    var h = parseFloat(svg.getAttribute('height'));
    if (!w || !h) {
      var r = svg.getBoundingClientRect();
      w = w || r.width;
      h = h || r.height;
    }
    if (w && h) clone.setAttribute('viewBox', '0 0 ' + w + ' ' + h);
  }

  // Strip scripts, event handlers, framework hooks (data-*, class) that reference the page
  var scripts = clone.querySelectorAll('script');
  for (var s = 0; s < scripts.length; s++) scripts[s].remove();
  var nodes = clone.querySelectorAll('*');
  for (var n = 0; n < nodes.length; n++) {
    var node = nodes[n];
    var kill = [];
    for (var a = 0; a < node.attributes.length; a++) {
      var name = node.attributes[a].name;
      if (name.indexOf('on') === 0 || name.indexOf('data-') === 0) kill.push(name);
    }
    kill.forEach(function (nm) { node.removeAttribute(nm); });
    node.removeAttribute('class');
  }
  // strip the same framework hooks from the root <svg> itself (querySelectorAll('*') excludes it)
  var rootKill = [];
  for (var ra = 0; ra < clone.attributes.length; ra++) {
    var rn = clone.attributes[ra].name;
    if (rn.indexOf('on') === 0 || rn.indexOf('data-') === 0) rootKill.push(rn);
  }
  rootKill.forEach(function (nm) { clone.removeAttribute(nm); });
  clone.removeAttribute('class');

  return clone.outerHTML;
}
