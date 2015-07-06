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
import module namespace lmc="http://dita-for-small-teams.org/xquery/modules/linkmgr-controller";
import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace preview='http://basex.org/modules/htmlpreview' at "htmlPreview.xqm";

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

declare
  %rest:path("/linkmgr/navtreeView/{$docURI=.+}")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function linkmgr:navtreeView($docURI as xs:string)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
   let $map := doc($docURI)
   let $tree := linkmgr:getMapNavTree($map)
   return
   <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Nav Tree for {df:getTitleText($map/*)}</title>
      <link rel="stylesheet" type="text/css" href="/static/style.css"/>
    </head>
    <body>
      <h1>Navigation Tree for "{df:getTitleText($map/*)}"</h1>
      {linkmgr:reportDocDetails($map)}
      <div class="tree">
       { $tree }
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
 : Document preview view
 :)
declare
  %rest:path("/linkmgr/docview/{$docURI=.+}/preview")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function linkmgr:docViewPreview($docURI as xs:string)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
   let $doc := doc($docURI)
   (: Apply preview XSLT to generate HTML from source doc :)
   return preview:elementToHTML($doc/*)
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
      { if (df:isMap($doc/*))
           then linkmgr:listMapDependencies($doc)
           else linkmgr:listTopicDependencies($doc)
      }
   </body>
 </html>
};

(:~
 : Document where-used view
 :)
declare
  %rest:path("/linkmgr/whereUsedView/{$docURI=.+}")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function linkmgr:docViewWhereUsed($docURI as xs:string)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
   let $doc := doc($docURI)
   let $title := df:getTitleText($doc/*)
   return
   <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Where-Used Report for Document {$title}</title>
      <link rel="stylesheet" type="text/css" href="/static/style.css"/>
    </head>
    <body>
      <h1>Where-Used Report for Document "{$title}"</h1>
      {linkmgr:reportDocDetails($doc)}
      <div>
        {if (df:isMap($doc/*))
            then linkmgr:listMapWhereUsed($doc)
            else linkmgr:listTopicWhereUsed($doc)}
      </div>
   </body>
 </html>
};

declare function linkmgr:listMapWhereUsed($doc as document-node()) as node()* {
  <div>
      <div class="listblock">
        <h4>Used As a Submap</h4>
        <!--
        <p>List of maps that use this map as a submap. Indicates
        whether the use is direct or indirect.</p> -->
        {
          (: Get local references by topicref links of format 'ditamap' and local scope :)
          let $useParams := map{'linktype' : ('topicref'),
                                'format' : ('ditamap'),
                                'scope' : ('local')
                               }
          let $uses := lmc:getUses($doc, $useParams)
          return linkmgr:useRecordsToHtml($uses)          
        }
      </div>
      <div class="listblock">
        <h4>Used as a Peer Map</h4>
        {
          (: Get local references by topicref links of format 'ditamap' and peer scope :)
          let $useParams := map{'linktype' : ('topicref'),
                                'format' : ('ditamap'),
                                'scope' : ('peer')
                               }
          let $uses := lmc:getUses($doc, $useParams)
          return linkmgr:useRecordsToHtml($uses)          
        }
      </div>
    </div>
};

declare function linkmgr:listTopicWhereUsed($doc as document-node()) as node()* {
  <div>
      <div class="listblock">
        <h4>Used from Maps</h4>
        {
          let $useParams := map{'linktype' : ('topicref'),
                                'format' : ('dita'),
                                'scope' : ('local')
                               }
          let $uses := lmc:getUses($doc, $useParams)
          return linkmgr:useRecordsToHtml($uses)          
        }
      </div>
      <div class="listblock">
        <h4>Used by Cross References</h4>
        {
          let $useParams := map{'linktype' : ('xref'),
                                'format' : ('dita'),
                                'scope' : ('local')
                               }
          let $uses := lmc:getUses($doc, $useParams)
          return linkmgr:useRecordsToHtml($uses)          
        }
      </div>
      <div class="listblock">
        <h4>Used by Content Reference</h4>
        {
          let $useParams := map{'linktype' : ('#conref')
                               }
          let $uses := lmc:getUses($doc, $useParams)
          return linkmgr:useRecordsToHtml($uses)          
        }
      </div>
    </div>
};

declare function linkmgr:listMapDependencies($doc as document-node()) as node()* {
  <div>
      <div class="listblock">
        <h4>DITA Topics</h4>
        <p>List of dita topics used from this map</p>
      </div>
      <div class="listblock">
        <h4>DITA Maps</h4>
        <p>List of dita topics used from this map</p>
      </div>
      <div class="listblock">
        <h4>Local-Scope Non-DITA Resources</h4>
        <p>List of local-scope non-DITA resources goes here</p>
      </div>
      <div class="listblock">
        <h4>External-Scope Resources</h4>
        <p>List of external-scope resources goes here</p>
      </div>
    </div>
};

declare function linkmgr:listTopicDependencies($doc as document-node()) as node()* {
   <div>
      <div class="listblock">
        <h4>Image References</h4>
        <p>List of referenced images goes here</p>
      </div>
      <div class="listblock">
        <h4>Cross references</h4>
        <p>List of cross references goes here</p>
      </div>
      <div class="listblock">
        <h4>Related Links</h4>
        <p>List of related links goes here</p>
      </div>
    </div>
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
        <h4>Root (Anonymous) Key Space</h4>
        <table>
          <thead>
            <th>Key Name</th>
            <th>Directly-addressed resource</th>
            <th>Ultimately-addressed resource</th>
            <th>Scope</th>
            <th>Topicmeta</th>
            <th>Conditions</th>
          </thead>
          <tbody>
          {
            let $keydefs := $doc//*[df:class(., 'map/topicref')][@keys]
            for $key in distinct-values(for $keydef in $keydefs return tokenize($keydef/@keys, ' '))
                let $keydef := ($keydefs[contains-token(@keys, $key)])[1]
                let $directResource := df:resolveTopicRef($keydef)('target')
                return 
                  <tr>
                    <td>{$key}</td>
                    <td>{if ($directResource) 
                            then linkmgr:makeLinkToDocSource(document-uri(root($directResource)))
                            else string(($keydef/@keyref, $keydef/@href)[1])
                        }</td>
                    <td>{
                      if ($keydef/@keyref)
                         then 'Keyref resolution not yet implemented'
                         else linkmgr:makeLinkToDocSource(document-uri(root($directResource)))
                    }</td>
                    <td>{df:getEffectiveAttributeValue($keydef, 'scope')}</td>
                    <td>{
                      let $linktext := $keydef/*[df:class(.,'map/topicmeta')]/*[df:class(.,'map/linktext')]
                      return if ($linktext)
                         then <div class="linktext">Link text: {string($linktext)}</div>
                         else ''
                    }
                    {
                       let $keywords := $keydef/*[df:class(.,'map/topicmeta')]/*[df:class(.,'map/keywords')]
                      return if ($keywords)
                         then <div class="linktext">
                           <span class="label">Keywords</span>
                           {for $keyword in $keywords/*
                                return (<br/>,<span class="keyword">{string($keyword)}</span>)
                           }
                         </div>
                         else ''
                    }
                    </td>
                    <td></td>
                  </tr>
          }
          </tbody>
        </table>
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
        class="value">{linkmgr:makeLinkToDocSource(document-uri($doc))}</span>
        <span>[<a href="/linkmgr/docview/{document-uri($doc)}/preview" target="preview">Preview</a>]</span></div>
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

declare function linkmgr:makeLinkToDocSource($docURI as xs:string?) as node()* {
     if ($docURI != '')
       then <a 
         target="sourceView" 
         href="/linkmgr/docview/{$docURI}/src">{bxutil:getPathForDocURI($docURI)}</a>
       else $docURI
};

declare function linkmgr:treeItemToHtml($treeItem as element()) as node()* {
    let $docURI := string($treeItem/properties/property[@name = 'uri'])
    return
    <li class="treeitem">
      <span class="label">{string($treeItem/label)}</span> 
      <span class="uri">[{linkmgr:makeLinkToDocSource($docURI)}]</span>
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

(:~
 : Constructs an HTML representation of the navigation tree of a DITA map.
 :)
declare function linkmgr:getMapNavTree($doc) as node()* {
   <ul class="navtree tree">
     {linkmgr:getNavTreeForTopicrefChildren($doc/*)}
   </ul>
};

(: Constructs a navigation tree list item for a sub amp :)
declare function linkmgr:getNavTreeForSubmap($topicref) as node()* {
   
   let $mapElem := df:resolveTopicRef($topicref)('target')
   return if ($mapElem)
      then linkmgr:getNavTreeForTopicrefChildren($mapElem)
      else ()
};

(: Constructs a navigation tree list item for a topicref :)
declare function linkmgr:getNavTreeForTopicGroup($topicref) as node()* {
  linkmgr:getNavTreeForTopicrefChildren($topicref)
};

declare function linkmgr:getNavTreeForTopicrefChildren($context as element()) as node()* { 
  for $child in $context/*[df:class(., 'map/topicref')][not(df:isResourceOnly(.))]
      return 
        if (df:isTopicGroup($child))
           then linkmgr:getNavTreeForTopicGroup($child)
           else if (df:isMapRef($child))
                then linkmgr:getNavTreeForSubmap($child)
                else linkmgr:getNavTreeForTopicref($child)
};

(: Constructs a navigation tree list item for a topicref :)
declare function linkmgr:getNavTreeForTopicref($topicref) as node()* {
  let $navTitle := df:getNavtitleForTopicref($topicref)
  let $format := df:getEffectiveAttributeValue($topicref, 'format')
  let $targetResource :=
      if ($format = 'dita')
         then 
            try {
             df:resolveTopicRef($topicref)('target')
            } catch * {
             ()
            }
         else () 
  let $resourceRef := 
      if ($topicref/@keyref != '')
        then concat('Keyref [', $topicref/@keyref, ']')
        else concat('URI ref "', $topicref/@href, '"')
  let $childNavTree := linkmgr:getNavTreeForTopicrefChildren($topicref)
  return
    <li class="treeitem navtreeitem">
      <span class="elemtype">[{name($topicref)}]</span>
      <span class="navtitle">{
        if ($navTitle != '')
           then $navTitle
           else if ($format = 'dita') 
                   then '{Resource not resolved}'
                   else concat($format, ' resource')
      }</span>      
      {
      (: FIXME: Is the resource can't be resolved, need to resolve the topicref
                to the URI of the ultimate target, if there is one.
       :)
      
      if (not(df:isTopicHead($topicref)))
           then 
            <span class="resource">{
            if ($targetResource)
                then linkmgr:makeLinkToDocSource(document-uri(root($targetResource)))
                else $resourceRef               
            }]</span>
           else ''}
      {if ($childNavTree)
          then
            <ul class="navtree tree {$topicref/@collection-type}">{
              $childNavTree
            }</ul>
          else ()
      }
    </li>
};

(: Format a set of use records as HTML. List may be empty :)
declare function linkmgr:useRecordsToHtml($uses as element()*) {

  if (count($uses) gt 0)
     then <table class="use-records">
     <thead>
      <th>Resource</th>
      <th>Link Type</th>
      <th>@format</th>
      <th>Scope</th>
      <th>Actions</th>
     </thead>
     <tbody>
       {for $use in $uses return linkmgr:useRecordToHtml($use)}
     </tbody>
     </table>
     else <p>Not used.</p>

};

(: Format a use record as HTML.:)
declare function linkmgr:useRecordToHtml($use as element()) {
   <tr class="use-record">
    <td><span class='title'>{string($use/title)}</span><br/>
    <span class="using-doc">{bxutil:getPathForDoc(doc(string($use/@usingDoc)))}</span><br/>
    <span class="use-locator">{string($use/@useLocator)}</span>
    </td>
    <td>{string($use/@linkType)}</td>
    <td>{string($use/@format)}</td>
    <td>{string($use/@scope)}</td>
    <td>[Action] [Action] [Action]</td>
  </tr>
};
