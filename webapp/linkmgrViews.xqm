(:~
 : DITA for Small Teams
 :
 : Link management application RESTXQ implementation.
 :
 : Copyright (c) 2015 DITA for Small Teams (dita-for-small-teams.org)
 :
 : See the BaseX RESTXQ documentation for details on how the RESTXQ 
 : mechanism works.
 :
 :)
module namespace linkmgr='http://basex.org/modules/linkmgr';

import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace linkutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";

declare
  %rest:path("/linkmgr/maptreeView/{$docURI=.+}")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function linkmgr:maptreeView($docURI as xs:string)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
   let $map := doc($docURI)
   let $tree := df:getMapTree($map)
   return
   <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Map Tree for {df:getTitleText($map/*)}</title>
      <link rel="stylesheet" type="text/css" href="/static/style.css"/>
    </head>
    <body>
      <h1>Map Tree for "{df:getTitleText($map/*)}"</h1>
      <div class="tree">
       { 
        linkmgr:treeToHtml($tree)        
       }
      </div>
   </body>
 </html>
};


(:~
 : Document source view
 :)
declare
  %rest:path("/linkmgr/docview/{$docURI=.+}/src")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function linkmgr:docViewSource($docURI as xs:string)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
   let $doc := doc($docURI)
   let $title := df:getTitleText($doc/*)
   return
   <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Source for Document {$title}</title>
      <link rel="stylesheet" type="text/css" href="/static/style.css"/>
    </head>
    <body>
      <h1>Source for Document "{$title}"</h1>
      <p>URI: {bxutil:getPathForDoc($doc)}</p>
      <div class="sourceblock">
        <pre>
        {serialize($doc)}
        </pre>
      </div>
   </body>
 </html>
};

(:~
 : Takes a generic tree XML structure and generates appropriate HTML
 : markup for it.
 :
 : A tree consists of a sequence of <treeItem> elements, where each tree item
 : has the structure:
 :
 : <treeItem>
 :   <label>label text</label>
 :   <properties>
 :    <prop name="name">value</prop>
 :   </properties>
 :   <children>
 :    <treeItem>
 :   </children>
 : </treeItem>
 :)
declare function linkmgr:treeToHtml($tree as element(mapTree)) as node()* {
    <ul class="tree">{
      for $treeItem in $tree/*
          return linkmgr:treeItemToHtml($treeItem)
    }</ul>
};

declare function linkmgr:treeItemToHtml($treeItem as element()) as node()* {
    let $docURI := string($treeItem/properties/property[@name = 'uri'])
    return
    <li class="treeitem">
      <span class="label">{string($treeItem/label)}</span> 
      <span class="uri">[<a 
         target="sourceView" 
         href="/linkmgr/docview/{$docURI}/src">{bxutil:getPathForDocURI($docURI)}</a>]</span>
      {if ($treeItem/children) 
          then
             <ul class="tree">{
             for $child in $treeItem/children/treeItem 
                   return linkmgr:treeItemToHtml($child)
             }</ul>
          else ()
      }
    </li>
};

