(: =====================================================

   DITA Link Management Utilities
   
   Utilities that support general DITA link management 
   actions.
   
   Author: W. Eliot Kimber
   
   Copyright (c) 2015 DITA For Small Teams
   Licensed under Apache License 2
   

   ===================================================== :)

module namespace lmutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";

import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";

(:
 : Find all links that use direct URI references to their target resources.
 :)
declare function lmutil:findAllDirectLinks($dbName) as element()* {
  let $db := db:open($dbName)
  (: First do direct URI references, which don't require any 
     context knowledge:
   :)
  let $links := collection($dbName)//*[df:isTopicRef(.) and not(@keyref)] |
                collection($dbName)//*[contains(@class, ' topic/xref ')] |
                collection($dbName)//*[contains(@class, ' topic/data-about ')] |
                collection($dbName)//*[contains(@class, ' topic/longdescref ')] |
                collection($dbName)//*[@conref]
   return $links
};

(: Given a link and the database that contains it, attempts
   to resolve the link to an element (in DITA a given link
   can address at most one element).
   
   Returns a map with the following members:
   'target': A sequence of zero or more elements addressed
             by the link.
   'log':    A sequence of zero or more log entry elements 
             generated by the resolution attempt.
 :)
declare function lmutil:resolveDirectLink($dbName, $link) as map(*) {

   let $resultMap := if (df:class($link, 'map/topicref'))
                      then df:resolveTopicRef($link)
                      else (df:resolveNonTopicRefDirectLink($link)
                      )
                     
   let $targets := $resultMap('target')
   let $log := (<info>Link: {
               concat('<', 
                      name($link), ' ',
                      lmutil:reportAtts($link, ('href', 'keyref', 'keys')), 
                      '>')} [class: "{string($link/@class)}"], doc: "{document-uri(root($link))}"</info>,
              if ($targets)
                 then <info>  Link resolved</info>
                 else $resultMap('log')
              )
   return map{'target' : $targets, 'log' : $log}
};

(: Construct a string report of the listed attributes :)
declare function lmutil:reportAtts($elem as element(), $attNames) as xs:string {
   let $result := for $att in $elem/@*
                      return if (name($att) = $attNames)
                                then concat(name($att), '="', string($att), '"')
                                else ()
   return string-join($result, ' ')
};

(: End of Module :)