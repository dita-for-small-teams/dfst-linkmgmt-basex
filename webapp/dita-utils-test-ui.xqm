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

module namespace page = 'http://basex.org/modules/web-page';

import module namespace html = 'dba/html';
import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace linkutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace dftest="http://dita-for-small-teams.org/xquery/modules/dita-utils-test" at "../test/src/xqy/dita-utils-test.xqm";

declare
  %rest:path("/test/dita-utils-test/{$repo}/{$branch}")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function page:testDitaUtils($repo as xs:string, $branch as xs:string)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>DITA Utils Test Using {$repo}/{$branch}</title>
      <link rel="stylesheet" type="text/css" href="/static/style.css"/>
    </head>
    <body>
      <div class="right">
      <p><a href="http://www.dita-for-small-teams.org" target="dfst-home">www.dita-for-small-teams.org</a></p>
      <p><img src="/static/dita_logo.svg" width="150"/></p>
      </div>
      <div class="title-block">
        <h2>DITA Utils Test Using {$repo}/{$branch}</h2>
      </div>
      <div class="action-block">
        <h3>Tests</h3>
        <div class="resultblock">
          <h4>testGetMapTree():</h4>
          <div class="result">
          <pre>
          { 
          let $mapTree := dftest:testGetMapTree($repo, $branch)            
          return serialize($mapTree)
  
          }
          </pre>
          </div>
        </div>
        <div class="resultblock">
          <h4>Key construction unit tests</h4>
          <div class="result">
            <p><b>df:constructKeyBinding($topicRef, $keyName)</b></p>
            <pre>{
             let $dbName := bxutil:getDbNameForRepoAndBranch($repo, $branch)
             let $map := doc(concat($dbName, "/docs/tests/complex_map/complex_map.ditamap"))
             let $topicRef := ($map//*[@keys])[1]
             return if ($topicRef)
                 then
                   let $keyName := tokenize($topicRef/@keys, ' ')[1]
                   let $keyBinding := df:constructKeyBinding($topicRef, $keyName)
                   return map:serialize($keyBinding)
                 else "No key-defining topicref found"

            }</pre>
          </div>
          <div class="result">
            <p><b>df:df:constructKeyDefinitionsForTopicref($topicRef as element())</b></p>
            <pre>{
             let $dbName := bxutil:getDbNameForRepoAndBranch($repo, $branch)
             let $map := doc(concat($dbName, "/docs/tests/complex_map/complex_map.ditamap"))
             let $topicRef := ($map//*[@keys])[1]
             return if ($topicRef)
                 then
                   let $keydefs := df:constructKeyDefinitionsForTopicref($topicRef)
                   return for $keydef in $keydefs return map:serialize($keydef)
                 else "No key-defining topicref found"

            }</pre>
          </div>
          <div class="result">
            <p><b>df:df:constructKeySpacesForTopicref($topicRef as element(), $keySpaces)</b></p>
            <pre>{
             let $dbName := bxutil:getDbNameForRepoAndBranch($repo, $branch)
             let $map := doc(concat($dbName, "/docs/tests/complex_map/complex_map.ditamap"))
             let $topicRef := ($map//*[@keys])[1]
             return if ($topicRef)
                 then
                   let $keyName := tokenize($topicRef/@keys, ' ')[1]
                   let $keyBinding := df:constructKeyBinding($topicRef, $keyName)
                   return map:serialize($keyBinding)
                 else "No key-defining topicref found"

            }</pre>
          </div>
        </div>
        <div class="resultblock">
          <h4>testConstructKeySpaces():</h4>
          <div class="result">
          <pre>
          { 
          let $keyspace := dftest:testConstructKeySpaces($repo, $branch)            
          return serialize($keyspace)
  
          }
          </pre>          
          </div>
          <div class="resultblock">
            <h4>Raw Key Space Map</h4>
          <pre>
          { 
             let $dbName := bxutil:getDbNameForRepoAndBranch($repo, $branch)
             let $map := doc(concat($dbName, "/docs/tests/complex_map/complex_map.ditamap"))             
             let $mapTree := df:getMapTree($map)
             let $keySpaces := df:constructKeySpacesForMapTree($mapTree) 
             return map:serialize($keySpaces)
          }</pre>
          </div>
        </div>
      </div>
    </body>
  </html>
};

