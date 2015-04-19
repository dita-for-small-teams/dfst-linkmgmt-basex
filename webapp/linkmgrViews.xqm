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
      {linkmgr:reportDocDetails($map)}
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
      {linkmgr:reportDocDetails($doc)}
      <div class="sourceblock">
        <pre>
        {serialize($doc)}
        </pre>
      </div>
   </body>
 </html>
};

(:~
 : Document dependency view
 :)
declare
  %rest:path("/linkmgr/dependencyView/{$docURI=.+}")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function linkmgr:docViewDependencies($docURI as xs:string)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
   let $doc := doc($docURI)
   let $title := df:getTitleText($doc/*)
   return
   <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Dependencies for Document {$title}</title>
      <link rel="stylesheet" type="text/css" href="/static/style.css"/>
    </head>
    <body>
      <h1>Dependencies for Document "{$title}"</h1>
      {linkmgr:reportDocDetails($doc)}
      <div class="listblock">
        <h4>Content references</h4>
        <p>List of content references goes here</p>
      </div>
      <div class="listblock">
        <h4>Cross references</h4>
        <p>List of cross references goes here</p>
      </div>
      <div class="listblock">
        <h4>Related Links</h4>
        <p>List of related links goes here</p>
      </div>
   </body>
 </html>
};

(:~
 : Document relationship table view
 :)
declare
  %rest:path("/linkmgr/reltableView/{$docURI=.+}")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function linkmgr:docViewReltables($docURI as xs:string)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
   let $doc := doc($docURI)
   let $title := df:getTitleText($doc/*)
   return
   <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Relationship Tables for Map {$title}</title>
      <link rel="stylesheet" type="text/css" href="/static/style.css"/>
    </head>
    <body>
      <h1>Relationship Tables for Map "{$title}"</h1>
      {linkmgr:reportDocDetails($doc)}
      <div class="listblock">
        <h4>Reltables</h4>
        <p>Relationship tables go here</p>
      </div>
   </body>
 </html>
};

(:~
 : Document relationship table view
 :)
declare
  %rest:path("/linkmgr/keyspaceView/{$docURI=.+}")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function linkmgr:docViewKeyspaces($docURI as xs:string)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
   let $doc := doc($docURI)
   let $title := df:getTitleText($doc/*)
   return
   <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Key Spaces for Map {$title}</title>
      <link rel="stylesheet" type="text/css" href="/static/style.css"/>
    </head>
    <body>
      <h1>Key Spaces for Map "{$title}"</h1>
      {linkmgr:reportDocDetails($doc)}
      <div class="listblock">
        <h4>Key Spaces</h4>
        <p>Key spaces go here</p>
      </div>
   </body>
 </html>
};

(:~
 : Constructs an HTML report of the details about a document
 :)
declare function linkmgr:reportDocDetails($doc as document-node()) as node()* {
   let $docURI := bxutil:getPathForDoc($doc)
   let $repo as xs:string := bxutil:getGitRepoForDoc($doc)
   let $branch as xs:string := bxutil:getGitBranchForDoc($doc)
   let $isDITA as xs:boolean := df:isDitaDoc($doc)
   return
    <div class="docdetails">
      <div><span class="label">URI:</span> <span
        class="value">{linkmgr:makeLinkToDocSource(document-uri($doc))}</span></div>
      <div><span class="label">Branch:</span> <span class="value">{$repo}/{$branch}</span></div>
      <div><span class="label">Is DITA:</span> <span class="value">{$isDITA}</span></div>
    </div>
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

declare function linkmgr:makeLinkToDocSource($docURI as xs:string) as node()* {
     <a 
         target="sourceView" 
         href="/linkmgr/docview/{$docURI}/src">{bxutil:getPathForDocURI($docURI)}</a>
};

declare function linkmgr:treeItemToHtml($treeItem as element()) as node()* {
    let $docURI := string($treeItem/properties/property[@name = 'uri'])
    return
    <li class="treeitem">
      <span class="label">{string($treeItem/label)}</span> 
      <span class="uri">[linkmgr:makeLinkToDocSource($docURI)]</span>
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

