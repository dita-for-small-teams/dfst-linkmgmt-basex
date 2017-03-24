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
module namespace preview='http://basex.org/modules/htmlpreview';

import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace lmutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";

declare function preview:elementToHTML($element as element()) as node()* {
  if (df:isTopic($element)) then preview:topicToHTML($element)
  else if (df:isMap($element)) then preview:mapToHTML($element)
  else preview:serializeXmlToHTML($element)
};

declare function preview:serializeXmlToHTML($element as element()) as node()* {
  <html xmlns="http://www.w3.org/1999/xhtml">
   <head>
     <title>{document-uri(root($element))}</title>
   </head>
   <body>
   <pre>
   {serialize($element)}
   </pre>
   </body>
 </html>

};

(:~
 : Generates an HTML preview of a DITA topic.
 : NOTE: This is a quick hack to avoid having to configure SAXON with BaseX,
 : which is the better solution for preview generation.
 :)
declare function preview:topicToHTML($topicElem as element()) as node()* {
  let $title := df:getTitleText($topicElem)
  return 
  <html xmlns="http://www.w3.org/1999/xhtml">
   <head>
     <title>{$title}</title>
     <link rel="stylesheet" type="text/css" href="/static/dita-divs.css"/>
   </head>
   <body>
   {preview:topicToHTMLMarkup($topicElem)}
   </body>
 </html>
};

declare function preview:topicToHTMLMarkup($topicElem as element()) as node()* {
  <div class="{$topicElem/@class}">
   {for $node in $topicElem/node()
        return preview:nodeToHTML($node)
    }
  </div>
};

(:~
 : Generates an HTML preview of a DITA map.
 : NOTE: This is a quick hack to avoid having to configure SAXON with BaseX,
 : which is the better solution for preview generation.
 :)
declare function preview:mapToHTML($mapElem as element()) as node()* {
  let $title := df:getTitleText($mapElem)
  return 
  <html xmlns="http://www.w3.org/1999/xhtml">
   <head>
     <title>{$title}</title>
   </head>
   <body>
   <p>Preview goes here</p>
   </body>
 </html>
};

declare function preview:nodeToHTML($node as node()) as node()* {
  typeswitch ($node)
    case text() return $node
    case processing-instruction() return () (: FIXME: Handle PIs :)
    case comment() return ()
    case element() return preview:htmlFromElement($node)
    default return() (: Ignore other node types :)
};

declare function preview:htmlFromElement($elem as element()) as node()* {

  let $effectiveElem as element() := lmutil:resolveContentReference($elem)
  return 
  <div class="{$effectiveElem/@class}">
    {for $att in $effectiveElem/@* except ($effectiveElem/@class)
         return preview:attributeToHTML($att)
    }
    {for $node in $effectiveElem/node()
         return preview:nodeToHTML($node)
    }
  </div>
};

declare function preview:attributeToHTML($att as attribute()) as node()* {
   <span class="attribute" data-attname="{name($att)}"
     ><span class="attvalue">{string($att)}</span></span>
};