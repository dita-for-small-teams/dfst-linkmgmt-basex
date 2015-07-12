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

(:~
 : Find all links that use direct URI references to their target resources.
 : Returns list of link item maps
 : 
 : Each link item map has the following items:
 : 
 : 'link' : The element that is the link
 : 'rootMap' : The root map document that defines the namespace the link
 :             is resolved in.
 : 'resolvedMap' : The fully-resolved map that defines key space the key
 :                 reference is resolved in.
 : 'keySpace' : The constructed key space for the root map.
 : 'processingRole' : For topicrefs, the @processing-role value. For
 :                    other links, 'normal'.
 : 'linkContext': The relevant container type for the link, one of:
 :                - 'title' : Link occurs within a title element
 :                - 'prolog' : Link occurs with topicmeta (maps) or prolog (topics)
 :                - 'shortdesc' : Link occurs within a short description
 :                - 'abstract' : Link occurs within an abstract (but not within a
 :                               short description within an abstract)
 :                - 'body' : Link occurs within a topic body
 :                - 'reltable' : Link is a topicref within a relationship table.
 :                - 'navtree' : Link is a topicref with @processing-role of 'normal' and
 :                              is not within a relationship table
 :                - 'resources' : Link is a topicref with a processing role of "resource-only". 
 :  'isDirect' : - 'true' if link is a direct URI reference
 :               - 'false' if link uses a resolvable key reference
 : 
 : For direct links the link element is sufficient
 : to allow resolution as use context has no affect on how the link is resolved.
 : For "." ("this topic") fragment IDs, the context is always the containing topic.
 : 
 : @param dbName Name of the database that contains the documents to be processed.
 : @param logID ID of the log to put log messages in.
 :)
declare function lmutil:findAllDirectLinks($dbName) as map(*)* {
  let $db := db:open($dbName)
  (: First do direct URI references, which don't require any 
     context knowledge:
   :)
  let $links := collection($dbName)//*[df:isTopicRef(.) and not(@keyref)] |
                collection($dbName)//*[contains(@class, ' topic/xref ') and (@href and not(@keyref))] |
                collection($dbName)//*[contains(@class, ' topic/data-about ') and (@href and not(@keyref))] |
                collection($dbName)//*[contains(@class, ' topic/longdescref ') and (@href and not(@keyref))] |
                collection($dbName)//*[@conref]
   (: Construct a link item map for each link element :)
   for $link in $links
       return map{'link': $link, 
                  'rootMap': (), 
                  'resolvedMap': (), 
                  'keySpace': (),
                  'processingRole': 
                     if (df:isTopicRef($link))
                        then if ($link/@processing-role)
                                then string($link/@processing-role)
                                else 'normal' (: Default for topicref :)
                        else 'normal', (: non-topicref links :)
                  'linkContext': lmutil:getLinkContext($link)
                 }
};


(:~
 : Given a link element, determines the linkContext value for it.
 :)
declare function lmutil:getLinkContext($link as element()) as xs:string {
  if (df:class($link, 'map/topicref'))
     then if ($link/ancestor::*[df:class(., 'map/reltable')])
             then 'reltable'
          else if ($link/@processing-role = ('resource-only'))
               then 'resources'
          else 'navtree'
     else if ($link/ancestor::*[df:class(., 'topic/title')])
          then 'title'
     else if ($link/ancestor::*[df:class(., 'topic/shortdesc')])
          then 'shortdesc'
     else if ($link/ancestor::*[df:class(., 'topic/abstract')])
          then 'abstract'
     else if ($link/ancestor::*[df:class(., 'topic/prolog') or df:class(., 'map/topicmeta')])
          then 'prolog'
     else if ($link/ancestor::*[df:class(., 'topic/body')])
          then 'body'
     else 'unknown-context'
      
};

(:~ 
 : Given a link item map, attempts to resolve the link to an element (in DITA a given link
 : can address at most one element).
 :  
 : Returns a map with the following members:
 : 'target': A sequence of zero or more elements addressed
 :           by the link.
 : 'log':    A sequence of zero or more log entry elements 
 :           generated by the resolution attempt.
 :)
declare function lmutil:resolveDirectLink($linkItem as map(*)) as map(*) {
  
    
   let $link as element()? := $linkItem('link')
   return if ($link)
      then
       let $resultMap := if (df:class($link, 'map/topicref') and ($link/@href))
                            then df:resolveTopicRef($link)
                            else df:resolveNonTopicRefDirectLink($link)
                         
       let $targets := $resultMap('target')
       let $log := (<info>Link: {
                   concat('<', 
                          name($link), ' ',
                          lmutil:reportAtts($link, ('href', 'keyref', 'keys', 'conref', 'scope')), 
                          '>')} [class: "{string($link/@class)}"], doc: "{document-uri(root($link))}"</info>,
                  if ($targets)
                     then <info>  Link resolved</info>
                     else $resultMap('log')
                  )
       return map{'target' : $targets, 'log' : $log, 'link' : $linkItem}
     else 
       map{'target' : (), 
                 'log' : (), 
                 'link' : $linkItem 
                }
};

(: Given a link descriptor map and the database that contains it, attempts
   to resolve the link to an element (in DITA a given link
   can address at most one element).
   
   Returns a map with the following members:
   'target': A sequence of zero or more elements addressed
             by the link.
   'log':    A sequence of zero or more log entry elements 
             generated by the resolution attempt.
   'link':   The input link item.
 :)
declare function lmutil:resolveIndirectLink($linkItem as map(*)) as map(*) {

   (: FIXME: Implement this function :)
   let $targets := ()
   let $log := ()
   return map{'target' : $targets, 'log' : $log , 'link' : $linkItem}
};

(:~
 : Given a database, finds all the indirect links. Returns a map
 : the the members:
 : 'links' : A sequence of maps, where each map represents one link.
 : 'log' : A sequence of log entry elements.
 : 
 : Each link map has the following items:
 : 
 : 'link' : The element that is the link
 : 'rootMap' : The root map document that defines the namespace the link
 :             is resolved in.
 : 'resolvedMap' : The fully-resolved map that defines key space the key
 :                 reference is resolved in.
 : 'keySpace' : The constructed key space for the root map.
 : 
 :)
declare function lmutil:findAllIndirectLinks($dbName) as map(*) {
   (: TBD: Implement 
   
1. Find all root maps (maps with no local-scope topicref references or
   maps with peer topicref references). This requires that the direct-reference
   use records are up to date. It also requires that the resolved map and key space
   documents have already been created.
   
2. For each root map, Walk the resolved map, creating link items for each key-based topicref.
   Resolve topicrefs to topics and process each topic to create link items for each key-based 
   link in each topic.   
   
   :)
   map{ 'link' : (), 
        'rootMap' : (),
        'resolvedMap' : (),
        'keySpace' : ()}
   
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