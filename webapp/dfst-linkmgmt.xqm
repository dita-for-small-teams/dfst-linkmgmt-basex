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
module namespace page = 'http://basex.org/modules/web-page';

import module namespace html = 'dba/html';
import module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";
import module namespace lmutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace linkmgr='http://basex.org/modules/linkmgr' at "linkmgrViews.xqm";
import module namespace lmm="http://dita-for-small-teams.org/xquery/modules/linkmgr-model";
import module namespace lmc="http://dita-for-small-teams.org/xquery/modules/linkmgr-controller";
import module namespace dfstcnst="http://dita-for-small-teams.org/xquery/modules/dfst-constants";




(:~
 : This function generates the welcome page.
 : @return HTML page
 :)
declare
  %rest:path("/")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function page:start()
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>DITA for Small Teams Link Manager</title>
      <link rel="stylesheet" type="text/css" href="static/style.css"/>
    </head>
    <body>
      <div class="right">
      <p><a href="http://www.dita-for-small-teams.org" target="dfst-home">www.dita-for-small-teams.org</a></p>
      <p><img src="static/dita_logo.svg" width="150"/></p>
      </div>
      <div class="title-block">
        <h2>DITA for Small Teams Link Manager</h2>
      </div>
      <div class="action-block">
        <div>
          <h3>Repositories and Branches</h3>
          <table>
            <thead>
              <tr>
                <th>Repository</th>
                <th>Branches</th>
              </tr>
            </thead>
            <tbody>
            {page:listReposAndBranches()}
           </tbody>
          </table>
        </div>
      </div>
    </body>
  </html>
};

declare
  %rest:path("/repo/{$repo}/{$branch}")
  %rest:query-param("infoMessage",    "{$infoMessage}")
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function page:branchMainView($repo as xs:string, $branch as xs:string, $infoMessage as xs:string?)
  as element(Q{http://www.w3.org/1999/xhtml}html)
{
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>DFST {$repo}/{$branch}</title>
      <link rel="stylesheet" type="text/css" href="/static/style.css"/>
    </head>
    <body>
      <div class="right">
      <p><a href="http://www.dita-for-small-teams.org" target="dfst-home">www.dita-for-small-teams.org</a></p>
      <p><img src="/static/dita_logo.svg" width="150"/></p>
      </div>
      <div class="title-block">
        <h2>Git repo {$repo}/{$branch}</h2>
      </div>
      <div class="management-actions">      
      [<a href="/repo/{$repo}/{$branch}/updateLinkManagementIndexes" 
            target="_updateLinkManagementIndexes"
            >Update Link Management Indexes</a>]
      [<a href="/repo/{$repo}/{$branch}/listAllLinks" 
            target="_listAllLinks"
            >List all links</a>]
      { if ($infoMessage and $infoMessage != '')
           then <p>{$infoMessage}</p>
           else ()
      }
      </div>
      <div class="action-block">
        <h3>DITA Maps</h3>
        <div class="listblock">
          <table class="listtable">
            <thead>
              <tr>
                <th>Title</th>
                <th>Path</th>
                <th>Root Map</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
            { if (false())
                 then <tr><td colspan="3">No maps found</td></tr>
                 else page:listMapsInBranch($repo, $branch)
            }
            </tbody>
          </table>
        </div>
        <h3>DITA Topics</h3>
        <div class="listblock">
          <table class="listtable">
            <thead>
              <tr>
                <th>Title</th>
                <th>Path</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
            { if (false())
                 then <tr><td colspan="3">No maps found</td></tr>
                 else page:listTopicsInBranch($repo, $branch)
            }
            </tbody>
          </table>
        </div>      </div>
    </body>
  </html>
};

(:~
 : List the databases that represent git repositories and branches
 : within those repositories.
 :
 : Result is a set of HTML table rows.
 :)
 declare function page:listReposAndBranches() as element()* {
 
    (: Get the repository info as an XML structure :)
    let $repos := bxutil:getGitRepositoryInfos()
    for $repo in $repos (: Sequence of <repo> elements :)
        let $branch := $repo/branch[1]
        let $path := concat($repo/@name, '/', $branch/@name)
        let $target := concat($repo/@name, '_', $branch/@name)
        return (
        <tr>
         <td rowspan="{$repo/@branchCount}">{string($repo/@name)}</td>
         <td><a href="/repo/{$path}" target="{$target}">{string($branch/@name)}</a></td>
        </tr>,        
        for $branch in $repo/branch[position() gt 1]
            let $path := concat($repo/@name, '/', $branch/@name)
            let $target := concat($repo/@name, '_', $branch/@name)
            return 
              <tr>
               <td><a href="/repo/{$path}" target="{$target}">{string($branch/@name)}</a></td>
              </tr>
        ) 
        (:
    <tr>
      <td rowspan="2">some repo</td>
      <td>master</td>
    </tr>,
    <tr>
      <td>develop</td>
    </tr>
    :)
 };

(:~
 : List the DITA maps within the specified branch of the specified repository.
 :
 : Result is a set of HTML table rows.
 :)
 declare function page:listMapsInBranch($repo as xs:string, $branch as xs:string) as element()* {
    let $dbName := bxutil:getDbNameForRepoAndBranch($repo, $branch)
    let $maps := df:getMaps($dbName)
    for $map in $maps
      let $docURI := document-uri($map)
      return <tr>
        <td>{df:getTitleText($map/*)}</td>
        <td>{linkmgr:makeLinkToDocSource(document-uri(root($map)))}</td>
        <td class="isRootMap">{
          let $resolvedMap as element()? := lmutil:getResolvedMapForMap($map/*)
          return if (not($resolvedMap))
             then "?"
             else if (lmc:isRootMap($map)) 
                     then '&#x2713;' 
                     else ''
        }</td>
        <td>
        [{html:linkToTarget('Navigation&#xa0;Tree', concat('/linkmgr/navtreeView/', document-uri($map)),
         'navtree')}] 
        [{html:linkToTarget('Map&#xa0;Tree', concat('/linkmgr/maptreeView/', document-uri($map)), 'maptree')}] 
        [{html:linkToTarget('Dependencies', concat('/linkmgr/dependencyView/', document-uri($map)), 'dependencies')}] 
        [{html:linkToTarget('Reltables', concat('/linkmgr/reltableView/', document-uri($map)), 'reltables')}] 
        [{html:linkToTarget('Key&#xa0;Spaces', concat('/linkmgr/keyspaceView/', document-uri($map)), 'keyspaces')}] 
        [{html:linkToTarget('Preview', concat('/linkmgr/docview/', document-uri($map), '/preview'), 'preview')}]
        [{html:linkToTarget('Where&#xa0;Used?', concat('/linkmgr/whereUsedView/', $docURI), 'whereused')}]
        </td>
      </tr>
 };

(:~
 : List the DITA topics within the specified branch of the specified repository.
 :
 : Result is a set of HTML table rows.
 :)
 declare function page:listTopicsInBranch($repo as xs:string, $branch as xs:string) as element()* {
    let $dbName := bxutil:getDbNameForRepoAndBranch($repo, $branch)
    let $topics := df:getTopicDocs($dbName)
    for $topic in $topics
      let $docURI := document-uri($topic)
      return <tr>
        <td>{df:getTitleText($topic/*)}</td>
        <td>{linkmgr:makeLinkToDocSource(document-uri(root($topic)))}</td>
        <td>[{html:linkToTarget('Where&#xa0;Used?', concat('/linkmgr/whereUsedView/', $docURI), 'whereused')}] 
            [{html:linkToTarget('Dependencies', concat('/linkmgr/dependencyView/', $docURI), 'dependencies')}] 
        [{html:linkToTarget('Preview', concat('/linkmgr/docview/', $docURI, '/preview'), 'preview')}] 
            </td>
      </tr>
 };

(:~
 : This function returns an XML response message.
 : @param $world  string to be included in the response
 : @return response element 
 :)
declare
  %rest:path("/linkmgr")
  %rest:GET
  function page:linkmgr(
    )
    as element(response)
{
  <response>
    <title>Linkmgr</title>
    <time>Link manager response: The current time is: { current-time() }</time>
  </response>
};

(: REST API to trigger creation or update of link management indexes. :)
declare
  %updating
  %rest:path("/repo/{$repo}/{$branch}/updateLinkManagementIndexes")
  %rest:GET
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function page:updateLinkManagementIndexes($repo as xs:string, $branch as xs:string) {
  
  let $contentDbName := bxutil:getDbNameForRepoAndBranch($repo, $branch)
  let $metadataDbName := bxutil:getMetadataDbNameForRepoAndBranch($repo, $branch)
  let $logID := "lmindex-update-log"

  
  return db:output(web:redirect(concat("/repo/", $repo, "/", $branch, "/updateLMIStage1"),
                                 map { 'contentDbName' : $contentDbName,
                                       'metadataDbName' : $metadataDbName,
                                       'logID' : $logID
                                     }))
};

(: Link management index stage 1: Clear the database and construct all 
 : direct link resource records. On return, redirects to stage 2.
 :)
declare
  %updating
  %rest:path("/repo/{$repo}/{$branch}/updateLMIStage1")
  %rest:query-param("contentDbName",  "{$contentDbName}")
  %rest:query-param("metadataDbName", "{$metadataDbName}")
  %rest:query-param("logID",          "{$logID}")
  %rest:GET
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function page:updateStage1($repo as xs:string, 
                             $branch as xs:string,
                             $contentDbName as xs:string,
                             $metadataDbName as xs:string,
                             $logID as xs:string) {
  

      try {
          lmc:updateLinkManagementIndexesStage1($contentDbName, $metadataDbName, $logID),
          db:output(web:redirect(concat("/repo/", $repo, "/", $branch, "/updateLMIStage2"),
                                 map { 'contentDbName' : $contentDbName,
                                       'metadataDbName' : $metadataDbName,
                                       'logID' : $logID
                                     }))
      } catch * {
          db:output(web:redirect("/error",
                                 map { 'contentDbName' : $contentDbName,
                                       'metadataDbName' : $metadataDbName,
                                       'error' : $err:description,
                                       'logID' : $logID
                                       
                                     }))
      }
      
  
};

(:~
 : Link management index update stage 2: Construct key spaces.
 : On return redirects to stage 3.  
 :)
declare
  %updating 
  %rest:path("/repo/{$repo}/{$branch}/updateLMIStage2")
  %rest:query-param("contentDbName",  "{$contentDbName}")
  %rest:query-param("metadataDbName", "{$metadataDbName}")
  %rest:query-param("logID",          "{$logID}")
  %rest:GET
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function page:updateStage2($repo as xs:string, 
                             $branch as xs:string,
                             $contentDbName as xs:string,
                             $metadataDbName as xs:string,
                             $logID as xs:string
                             ) {
   try {
                             
      lmc:updateLinkManagementIndexesStage2(
         $contentDbName,
         $metadataDbName,
         $logID),
      db:output(web:redirect(concat("/repo/", $repo, "/", $branch, "/updateLMIStage3"),
                                       map { 'contentDbName' : $contentDbName,
                                             'metadataDbName' : $metadataDbName,
                                             'logID' : $logID
                                           }))      
    } catch * {
          db:output(web:redirect("/error",
                                 map { 'contentDbName' : $contentDbName,
                                       'metadataDbName' : $metadataDbName,
                                       'error' : $err:description,
                                       'logID' : $logID
                                       
                                     }))
    }

};

(:~
 : Link management index update stage 3: Construct indirect link
 : where-used records.
 : On return redirects back to the page for the repo and branch.
 :)
declare
  %updating 
  %rest:path("/repo/{$repo}/{$branch}/updateLMIStage3")
  %rest:query-param("contentDbName",  "{$contentDbName}")
  %rest:query-param("metadataDbName", "{$metadataDbName}")
  %rest:query-param("logID",          "{$logID}")
  %rest:GET
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function page:updateStage3($repo as xs:string, 
                             $branch as xs:string,
                             $contentDbName as xs:string,
                             $metadataDbName as xs:string,
                             $logID as xs:string
                             ) {

    try {
                            
      (lmc:updateLinkManagementIndexesStage3($contentDbName, $metadataDbName, $logID),
       db:output("Link management database updated"))
      (:,
      db:output(web:redirect(concat("/repo/", $repo, "/", $branch),
                                       map { 'infoMessage' : 'Link management indexes updated'
                                           }))
                                           :)
            
    } catch * {
          db:output(web:redirect("/error",
                                 map { 'contentDbName' : $contentDbName,
                                       'metadataDbName' : $metadataDbName,
                                       'error' : $err:description,
                                       'logID' : $logID
                                       
                                     }))
    }

};

(:~ 
 : Generic error report page. This is a placeholder in advance of more sophisticated
 : error reporting infrastructure.
 :)
declare
  %rest:path("/error")
  %rest:query-param("contentDbName",    "{$contentDbName}")
  %rest:query-param("metadataDbName", "{$metadataDbName}")
  %rest:query-param("error", "{$error}")
  %rest:GET
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function page:reportError($contentDbName as xs:string?,
                            $metadataDbName as xs:string?,
                            $error as xs:string?
                           ) {
  <html>
   <head>
     <title>Error</title>
   </head>
   <body>
    <h1 style="color: red;">Error</h1>
    <div>
      <p>Error</p>
      <p>content database: {$contentDbName}</p>
      <p>Metadata database: {$metadataDbName}</p>
      <p>Error message: {$error}</p>
    </div>
   </body>
  </html>
};

declare function page:formatLogAsHtml($log) as element() {
  <pre>
  {for $entry in $log/*
       return concat('[', upper-case(name($entry)), ']', ' ', string($entry), '&#x0a;')
  }
  </pre>

};

