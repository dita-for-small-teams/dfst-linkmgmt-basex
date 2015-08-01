(: =====================================================

   DITA Link Manager View
   
   View component of Model/View/Controller. Does rendering
   of link management data for a specific rendition
   target (e.g, HTML pages)
      
   Author: W. Eliot Kimber
   
   Copyright (c) 2015 DITA For Small Teams
   Licensed under Apache License 2
   

   ===================================================== :)

module namespace lmv="http://dita-for-small-teams.org/xquery/modules/linkmgr-view";

import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace lmutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace lmm="http://dita-for-small-teams.org/xquery/modules/linkmgr-model";
import module namespace dfstcnst="http://dita-for-small-teams.org/xquery/modules/dfst-constants";
import module namespace lmc="http://dita-for-small-teams.org/xquery/modules/linkmgr-controller";

declare namespace dfst="http://dita-for-small-teams.org";

declare function lmv:formatKeySpacesForMap($doc) as node()* {
      let $thead := 
          <thead>
            <th>Key Name</th>
            <th>Directly-addressed resource</th>
            <th>Ultimately-addressed resource</th>
            <th>Scope</th>
            <th>Topicmeta</th>
            <th>Properties</th>
          </thead>
      let $rootKeySpace as element() := lmc:getKeySpaceForMap($doc)
      for $keySpace as element() in $rootKeySpace/descendant-or-self::keyspace
          let $scopeNames as xs:string* := 
              for $e in $keySpace/scopeNames/scopeName
                  return string($e)
          let $labelPrefix := 
              if (not($keySpace/ancestor::*))
                 then 'Root (Anonymous) Key Space'
                 else 'Nested Key Space: '
          let $scopeNames := string-join($scopeNames, ', ')
          return                  
            <div class="listblock">
              <h4>{$labelPrefix}{$scopeNames}</h4>
              <table>
                {$thead}
                <tbody>
                {
                  let $keys := $keySpace/keys/key
                  return if (not($keys))
                     then <tr><td colspan="6" style="text-align: center;">No keys defined in key space</td></tr>
                     else 
                       for $key in $keys
                           let $defCount := count($key/keydef)
                           let $firstDef := $key/keydef[1]
                           return 
                             (<tr>
                               <td>
                               {if ($defCount gt 1)
                                   then attribute rowspan {$defCount}
                                   else ()}
                               {string($key/@name)}
                               </td>
                               {lmv:makeKeyDefTableEntries($firstDef)}
                             </tr>,
                             for $keyDef in $key/keydef[position() > 1]
                                 return lmv:makeKeyDefTableEntries($keyDef)
                             )
                }
                </tbody>
              </table>
            </div>
};

declare function lmv:makeKeyDefTableEntries($keydef as element()) as element()* {
   let $result := (
     <td>{(: Directly-addressed resource :)
       string($keydef/@href)
     }</td>,
     <td>{(: Indirect-addressed resource :)
       string($keydef/@keyref)
     }</td>,
     <td>{(: Scope :)
        df:getEffectiveScope($keydef)
     }</td>,
     <td>{(: topicmeta :)
       lmv:formatTopicmetaToHTML($keydef/*[df:class(., 'map/topicmeta')])
     }</td>,
     <td>{(: Conditions :)
        lmv:formatKeydefAtts($keydef)
     }</td>)
   return $result
};

declare function lmv:formatTopicmetaToHTML($topicmeta as element()?) as node()* {
  let $result :=
    if ($topicmeta)
       then (: FIXME: Really format this stuff. This is a quick hack :) 
         <p>{string($topicmeta)}</p>
       else ()
   return $result
};

declare function lmv:formatKeydefAtts($keydef as element(keydef)) as xs:string {
    let $result :=
    string-join(
        for $att in $keydef/@*[not(name(.) = ('class', 'processing-role', 'scope', 'keyref', 'href', 'keys'))]                     
            return concat(name($att), '="', string($att)), ' ')     
     return $result
};




(: End of Module :)