(:============================================
 : DITA for Small Teams DITA Utils Test Driver
 :
 : Provides tests and test utilities for exercising
 : the dita-utils.xqm functions.
 :
 : Copyright (c) 2015 DITA For Small Teams
 :
 : These tests depend on the files from the dfst-sample-project
 : project under the tests/ directory.
 :
 :)

module namespace dftest="http://dita-for-small-teams.org/xquery/modules/dita-utils-test";

import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace linkutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace relpath="http://dita-for-small-teams.org/xquery/modules/relpath-utils";


declare function dftest:testResolveTopicOrMapUri($repo as xs:string, $branchName as xs:string) as node()* {
  
   let $dbName := bxutil:getDbNameForRepoAndBranch($repo, $branchName)
   let $db := db:open($dbName)
   let $map := doc(concat($dbName, "/docs/tests/complex_map/complex_map.ditamap"))
   (: return text { resolve-uri('foo', 'dfst^dfst-sample-project^develop/docs/tests/complex_map/complex_map.ditamap')} :)
   let $tr := (($map/*/*[df:class(., 'map/topicref')])[2]/*[df:isTopicRef(.)])[1]
   let $targetUri := df:getEffectiveTargetUri($tr)
   let $result := df:resolveTopicOrMapUri($tr, $targetUri)
   return $result
   (: :)
};

declare function dftest:xmlToHtmlCode($nodes as node()*) as node()* {
  <pre>{
  for $node in $nodes
      return dftest:nodeToHtml($node)
  }</pre>
};

declare function dftest:nodeToHtml($node as node()) as node()* {
  typeswitch ($node) 
   case(text()) return $node
   case(document-node()) return dftest:docToHtml($node)
   case(element()) return dftest:elemToHtml($node)
   case(comment()) return dftest:commentToHtml($node)
   case(processing-instruction()) return dftest:piToHtml($node)
   case(attribute()) return dftest:attToHtml($node)
   default return text { "unknown node type" }
};

declare function dftest:docToHtml($node as document-node()) as node()* {
  for $child in $node/node() return dftest:nodeToHtml($child)
};

declare function dftest:elemToHtml($node as element()) as node()* {
  (
    text {
      concat("&lt;", 
             name($node))             
    },
    for $att in $node/@* return dftest:attToHtml($att),
    if (string($node) = '' and count($node/node()) = 0) 
       then text { concat("/&gt;", out:nl()) }
       else (
          text {
            concat("&gt;", out:nl())
          },
          for $child in $node/node() return dftest:nodeToHtml($child),
          text {
            concat("&lt;/", name($node), "&gt;", out:nl())
          }
       )
  )
};

declare function dftest:attToHtml($node as attribute()) as node()* {
  text {
  concat(" ", name($node), '="', string($node), '"', out:nl())
  }
};

declare function dftest:piToHtml($node as processing-instruction()) as node()* {
  text {
   concat('&lt;?', name($node), ' ', string($node), out:nl())
  }
};

declare function dftest:commentToHtml($node as comment()) as node()* {
  text {
   concat('&lt;--', string($node), '--&gt;', out:nl())
  }
};


