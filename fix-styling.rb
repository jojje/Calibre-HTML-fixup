#!/usr/bin/ruby
#
# Post-processing of Calibre intermediate HTML, so it gets readable.
#
# Depends on:
# - Nokogiri (gem install nokogiri)
# - a locally available copy of jQuery (http://code.jquery.com/jquery-1.6.2.min.js)
#   Or the script could be changed to reference the provided URL instead.
#
# Copyright (c) 2011 Jonas Tingeborn
# Provided under the MIT license (http://www.opensource.org/licenses/mit-license.php)
#

require 'rubygems'
require 'nokogiri'
require 'fileutils'

JQUERY_FILE = "jquery-1.6.2.min.js"
INPUT_DIR   = "html/input"
OUTPUT_DIR  = "html/input"
DEVNULL     = if RUBY_PLATFORM =~ /mingw/ then "NUL" else "/dev/null" end

def main
  inf  = File.join INPUT_DIR, 'dummy.html'
  outf = File.join OUTPUT_DIR, 'book.html'
  cmd = 'tidy -i -wrap 120 -utf8 %s > %s 2>%s' % [inf,outf,DEVNULL]
  system(cmd)  # Tidy exits with non-zero for warnings as well
  inject_scripts(outf);
end

def inject_scripts(fn)
  dir = File.join File.dirname(fn), 'js'
  script_fn = File.join(dir, "fixup.js")
  
  # Copy static script asset
  Dir.mkdir dir unless File.exists?(dir)
  FileUtils.copy JQUERY_FILE, File.join(dir,JQUERY_FILE)
  open(script_fn,'w'){|f| f.puts(script) }
  
  # Inject scripts into doc
  doc = open(fn){|f| Nokogiri(f) }
  %w[ jquery-1.6.2.min.js fixup.js].each do |url|
    el = doc.create_element('script', {:type=>"text/javascript", :src=>"js/"+url})
    doc.css('head')[0].add_child(el)             # Reference our custom script instance in the html doc.
  end
  doc.css('body')[0]['style'] = "display:none"   # Don't show the unformatted page initially, to avoid flicker.
  open(fn,'wb'){|f| f.write(doc.to_s) }
end

def script
<<EOF
/**
 * Post-processes e-book HTML documents when they are opened in a browser.
 *
 * Include this script as well as jQuery into the page to be fixed up, such as:
 * <script type="text/javascript" src="jquery-1.6.2.min.js"></script>
 * <script type="text/javascript" src="fixup.js"></script>
 *
 * Performance indication of the script on a 852 page book:
 *  - Google Chrome 12 took was the fastest overall and needed 3.4s to load, process and display the page, 
 *      of which 1.5s was spent running this script and 1.9s for loading the HTML and rendering the page.
 *  - Firefox 5 was 18% slower than Chrome and needed 4s to load, process and display the page, 
 *      of which 1.2s was spent running this script and 2.8s loading the HTML and rendering the page.
 *  - IE 9 was 4.4 times slower than Chrome and needed 15s to load, process and display the page, 
 *      of which 3.4s was spent running this script and 11.6s loading the HTML and rendering the page.
 */
(function(){

  // Per-book custom layout fixup.
  function fixLayout() {
    
    function colorDiv() {
      var args = $.makeArray(arguments), clazz = args.shift();
      args.forEach(function(s){
        $('h3:contains('+ s +')').closest('div').addClass(clazz);
      });
    }
    
    $('<style type="text/css"></style>').appendTo('head').html(
      'tt {font-size: 1.2em !important; margin-top:1em;}'+
      'body {font-family: arial; font-size: 0.8em;}'+
      'code {font-size: 1.2em;}'+
      'table { border-collapse: collapse; }'+
      'th {text-align: left;}'+
      'th,td {padding: 0.2em;}'+
      'hr {display:none;}'+
      '.code-block { margin-top: 1em; margin-left: 1em; }'+
      '.tip  { background-color: #E0FFE0; }'+
      '.note { background-color: #FFFFDD; }'+
      '.warn { background-color: #FFDDDD; }'+
      '.tip,.note,.warn {  }'
    );
    
    var root = $('#content').remove();                   // Detaching the tree to be manipulated speeds up the performance several orders on IE.
    $('tt code',root).contents().unwrap();               // Remove unecessary code elements around the text nodes in a tt-code segment
    $('td > p > font',root).unwrap();                    // Remove unecessary paragraph in table cells
    $(document.body).append(root);                       // Re-attached the container again
  
    $('font[size]').removeAttr('size');                 // Remove hard-coded size attributes
    $('tt').closest('div').addClass('code-block');
    colorDiv('tip', 'Tip');
    colorDiv('note', 'Note');
    colorDiv('warn', 'Warning', 'Caution');
    $('#content').prepend($('img:last').remove());      // Move book image to the top
    
    // Document specific fixups
    $('table').get().slice(0,0).forEach(function(table){
      $(table).removeAttr('border');
    }); 
  } // fixLayout
  
  function timeit(f){
    var st = new Date();
    f();
    if(window.console && console.info) {
      console.info("Seconds needed to for on-the-fly layout fixup: " + ((new Date()) - st));
    }
  }
  
  // Need to make the document tidying optional for IE since that browser is painfully
  // slow at loading the raw HTML document, *as well* as executing the javascript logic.
  function startRendering(){
    $('body > *').wrapAll('<div id="content" style="display:none"></div>');
    $('body').removeAttr('style');
    var flash = $('<div>Adjusting book styling, please wait ...</div>')
      .appendTo('body')
      .attr('style','position:absolute; padding:1em; font-size:2em; font-style:italic; top: 0em; z-index: 999;')
    setTimeout(function(){
      timeit(function(){
        fixLayout();
        flash.remove();
        $('#content').removeAttr('style');
      });
    },1);
  }
  
  $(document).ready(function(){
    if( $.browser.msie ) {           // Since IE is so horribly slow, we need to give the user the *option* of prettying up the book, not mandate it.
      var cont   = $('<div></div>');
      var label  = $('<em> Warning, it might take about 10-20 seconds to re-render the page in Internet Explorer. If possible, use another browser to read this book</em>');
      var button = $('<input type="button" value="Fix layout"></input>').click(function(){
        cont.remove();
        startRendering();
      });
      cont.append(button).append(label);
      $('body').prepend(cont);
      $('body').removeAttr('style');
    } else startRendering();
  });
})();
EOF
end

main

