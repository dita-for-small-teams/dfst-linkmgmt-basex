
  let $grammars := collection('/db/apps/dita-test-01/doctypes/rng/')/rng:grammar[dita:moduleDesc and
                                not(matches(dita:moduleDesc/dita:moduleMetadata/dita:moduleType, 'shell'))]
  
  let $grammar := $grammars[rnginsp:getModuleShortName(.) = 'sw-d']
  let $element := ($grammar//rng:element)[1]
  let $tagname := $element/@name
  let $ignoredAtts := ('class', 'domains', 'dita:DITAArchVersion')
  let $phraseTypes := for $element in $grammars//rng:element
          let $class := rnginsp:getDITAClass($element)
          return if (starts-with($class, '+') and contains($class, ' topic/ph '))
                 then $element
                 else ()
  
  return <result>{(
  (:
  <base type="topic/ph">{
     for $element in $phraseTypes
          return rnginsp:getElementDeclarationSummary($element, (attribute allows-keyref{rnginsp:allowsAttribute($element, 'keyref')}))
  }</base>, :)
  <defaultedAttributes xmlns="http://relaxng.org/ns/structure/1.0" xmlns:a="http://relaxng.org/ns/compatibility/annotations/1.0">{
     for $element in $grammars//rng:element
         let $defines := rnginsp:resolveLocalRefs($element//rng:ref[@name = concat($element/@name, '.attlist')])
         let $attdecls := ($element, $defines//rng:attribute[not(string(@name) = $ignoredAtts)][@a:defaultValue != ''])
         return if (count($attdecls) gt 1)
                   then <element name="{$element/@name}">{$attdecls[position() gt 1]}</element>
                   else ''
         
         
    
  }</defaultedAttributes>,
  (: rnginsp:elementDeclarationReport($grammars), :)
  ''
  )
  }</result>
