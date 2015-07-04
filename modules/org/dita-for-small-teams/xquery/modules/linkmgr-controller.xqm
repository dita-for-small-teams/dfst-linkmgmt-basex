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
   let $resKey := lmc:constructResourceKeyForElement($doc/*)
   
   (: Now find all use records for the resource key that match the filter
      specification. 
        
      Implementation question: How to know if the use records for the 
      resource are up to date?
      :)
   
   (: Stub use record for initial testing :)
   
   return <useRecord usekey="uniqueIDofTheUseInstance"
                     reskey="resourceKeyOfReferencedResource"
                     linktype="- map/topicref bookmap/chapter "
                     format="ditamap"
                     scope="local"
                     usingDoc="URI of the doc that contains the reference"
                     useLocator="XPath location of the using element within the using doc">
            <title>Title of using document (or relative path if no title)</title>
          </useRecord>

};

(: Given an element with an @id value, construct the unique resource key for it. 
   For a given element the resource ID is guaranteed to be unique within
   a snapshot (git commit).

   @param elem Element to get resource ID for. Must specify @id attribute.
   @returns Resource key string. 

   The resource key is a combination of the absolute URI of the containing
   document, the element's @id attribute value, and other details TBD.
   
   Note that because DITA can only address elements with IDs this function
   only works for elements with @id attribute values.
 :)
declare function lmc:constructResourceKeyForElement($elem as element()) as xs:string {
  'bogusresourcekey'
};

(: End of Module :)