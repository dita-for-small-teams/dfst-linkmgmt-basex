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
declare function linkmgr:treeToHtml($treeItems as element()*) as node()* {
    <ul>{
      for $treeItem in $treeItems
          return linkmgr:treeItemToHtml($treeItem)
    }</ul>
};

declare function linkmgr:treeItemToHtml($treeItem as element()) as node()* {
    <li class="treeitem">
      <span class="label">{string($treeItem/label)}</span> 
      <span class="uri">[{string($treeItem/properties/property[@name = 'uri'])}]</span>
      {if ($treeItem/children) 
          then linkmgr:treeToHtml($treeItem/children/treeItem)
          else ()
      }
    </li>
};

