(: =====================================================

   DITA Link Manager Controller
   
   Controller component of Model/View/Controller. Manages
   access to the link manager data models used to optimize
   link manager features (where-use, dependency tracking).
   
   Author: W. Eliot Kimber
   
   Copyright (c) 2015 DITA For Small Teams
   Licensed under Apache License 2
   

   ===================================================== :)

module namespace lmc="http://dita-for-small-teams.org/xquery/modules/linkmgr-controller";

import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace linkutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace lmm="http://dita-for-small-teams.org/xquery/modules/linkmgr-model";

declare namespace dfst="http://dita-for-small-teams.org";


(: Give a document, finds all references to that document that match the 
   type of uses as configured in the $useParams.
   
   @param doc Document to find uses of. 
   @param useParams Use filter parameters. Only uses that match the parameters 
                    will be reported.
   @return Zero or more use record elements. 
   
   The use parameters are:
   
   linktype: List of base type names (e.g., 'topicref, xref) or qualified
             class names (e.g., 'map-d/navref') of the types of links
             to report usage for. If unspecifed, all link types are reported.
             The keyword "#conref" indicates uses via @conref or @conkeyref
             
   format:   List of @format values by which the document is used, e.g. "dita", "ditamap",
             etc. If unspecified, uses are not filtered by @format value.
             
   scope:    List of @scope values to filter the uses by. If unspecified, uses are not
             filtered by @scope value.
             
   TBD: Need for direct/indirect filter, other filters.          
   
   
 :)
declare function lmc:getUses($doc as document-node(), $useParams) as element()* {

   let $linktypes := if ($useParams('linktype')) 
                        then $useParams('linktype') 
                        else ('#any')
   let $formats   := if ($useParams('format')) 
                        then $useParams('format') 
                        else ('#any')
   let $scopes   := if ($useParams('scope')) 
                        then $useParams('scope') 
                        else ('#any')

   (: Note that all references are ultimately to elements,
      so resource keys are always for elements, not
      documents. Given an element we can always get its
      containing document.
      
      In DITA, except for <dita> documents, references to 
      documents with no fragment identifier are implicitly
      to the root elements of those documents (i.e., a map
      or topic element).
    :)
   let $resKey := lmm:constructResourceKeyForElement($doc/*)
   
   (: Now find all use records for the resource key that match the filter
      specification. 
        
      :)
    let $dbName := bxutil:getMetadataDbNameForDoc($doc)
    let $records := collection($dbName)/dfst:useRecord[@resourceKey = $resKey]
                                       [lmc:useRecordMatcher(., $linktypes, $formats, $scopes)]   
    return $records

};

(:~
 : Determines if a given where-used record matches the filter
 : specified parameters. 
 :)
declare function lmc:useRecordMatcher($record as element(),
                                              $linktypes as xs:string*,
                                              $formats as xs:string*,
                                              $scopes as xs:string*) as xs:boolean {
   let $result := ((if ($linktypes = '#any')
                       then true()
                       else string($record/@linkType) = $linktypes) and
                   (if ($formats = '#any')
                       then true()
                       else string($record/@format) = $formats) and
                   (if ($scopes = '#any')
                       then true()
                       else string($record/@scope) = $scopes))
  return $result                       
};

(: End of Module :)