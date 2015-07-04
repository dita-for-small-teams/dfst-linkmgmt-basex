(: Queries for inspecting the DITA RELAX NG schemas :)

module namespace rnginsp="http://dita-for-small-teams.org/xquery/modules/inspect-rng";

declare namespace a="http://relaxng.org/ns/compatibility/annotations/1.0";
declare namespace dita="http://dita.oasis-open.org/architecture/2005/";
declare namespace rng="http://relaxng.org/ns/structure/1.0";

declare function rnginsp:getElementDefinitionPattern($grammar, $tagname) as element(rng:define) {
   let $patternName := concat($tagname, '.element')
   let $define := $grammar//rng:define[@name = $patternName]
   return $define
};


(: Resolve a ref within the same grammar document. The reference
   is resolved recursively.

   Input is an rng:ref elements.
   
   Result is the elements referenced, as a sequence
:)
declare function rnginsp:resolveLocalRef($ref as element(rng:ref), $alreadyFound as node()*) as element()* {
       let $targetName := string($ref/@name)
       let $targets := root($ref)//rng:define[@name = $targetName] except ($alreadyFound)
       for $target in $targets
           return ($targets , 
                   for $subref in $target//rng:ref
                       return rnginsp:resolveLocalRef($subref, ($targets | $alreadyFound)))
};

(: Resolve refs within the same grammar document. The references
   are resolved recursively.

   Input is one or more rng:ref elements. 
:)
declare function rnginsp:resolveLocalRefs($refs as element(rng:ref)*) as element()* {
   for $ref in $refs
       return rnginsp:resolveLocalRef($ref, ())
};

declare function rnginsp:getModuleShortName($grammar as element(rng:grammar)) as xs:string {
   let $moduleDesc := $grammar/dita:moduleDesc
   let $moduleShortName as xs:string := string($moduleDesc/dita:moduleMetadata/dita:moduleShortName)
   return $moduleShortName
};

(: Given the rng:element declaration for an element type, get the @class attribute declaration.
:)
declare function rnginsp:getDITAClass($elementDecl as element(rng:element)) as xs:string {
   let $tagname := string($elementDecl/@name)
   let $defines := rnginsp:resolveLocalRefs($elementDecl/rng:ref[@name = concat($tagname, '.attlist')])
   let $classAtt := ($defines//rng:attribute[@name = 'class'])[1]
   let $classValue := $classAtt/@a:defaultValue
   return ($classValue, 'No @class value')[1]
};

declare function rnginsp:allowsAttribute($elementDecl as element(rng:element), $attname as xs:string) as xs:boolean {
   let $tagname := string($elementDecl/@name)
   let $defines := rnginsp:resolveLocalRefs($elementDecl/rng:ref[@name = concat($tagname, '.attlist')])
   let $attdecls := ($defines//rng:attribute[@name = $attname])
   
   return count($attdecls) gt 0
};

declare function rnginsp:getElementDeclarationSummary($element as element(rng:element)) as node()* {
  rnginsp:getElementDeclarationSummary($element, ())
};

declare function rnginsp:getElementDeclarationSummary($element as element(rng:element), $additionalAtts as attribute()*) as node()* {
   <element name="{$element/@name}" 
                     module="{tokenize(document-uri(root($element)), '/')[last()]}"
                     class="{rnginsp:getDITAClass($element)}"
   >{$additionalAtts}</element>
};

declare function rnginsp:elementDeclarationReport($grammars as element(rng:grammar)*) as node()* {
 <element-summary>{
 let $elements := for $grammar in $grammars return $grammar//rng:element[@name]
 let $moduleNames := for $grammar in $grammars return rnginsp:getModuleShortName($grammar) 
 return ( 
   attribute total-element-types {count($elements)},
   attribute modules {string-join($moduleNames, ' ')}, 
   <all-elements>{
     for $element in $elements order by lower-case($element/@name)
         return rnginsp:getElementDeclarationSummary($element)
   }</all-elements>,
   <elements-by-module>{
     for $grammar in $grammars order by rnginsp:getModuleShortName($grammar)
         return <module name="{rnginsp:getModuleShortName($grammar)}">{
                for $element in $grammar//rng:element order by lower-case($element/@name)
                        return rnginsp:getElementDeclarationSummary($element)
                     }</module>
   }</elements-by-module>
      )
 }</element-summary>
 
};

(: ============== End of Module =================== :)