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
import module namespace linkutil="http://dita-for-small-teams.org/xquery/modules/linkmgmt-utils";
import module namespace df="http://dita-for-small-teams.org/xquery/modules/dita-utils";
import module namespace linkmgr='http://basex.org/modules/linkmgr' at "linkmgrViews.xqm";


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
  %output:method("xhtml")
  %output:omit-xml-declaration("no")
  %output:doctype-public("-//W3C//DTD XHTML 1.0 Transitional//EN")
  %output:doctype-system("http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd")
  function page:branchMainView($repo as xs:string, $branch as xs:string)
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
      <div class="action-block">
        <h3>DITA Maps</h3>
        <div class="listblock">
          <table class="listtable">
            <thead>
              <tr>
                <th>Path</th>
                <th>Title</th>
                <th>Is Root?</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
            { if (false())
                 then <tr><td colspan="4">No maps found</td></tr>
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
                <th>Path</th>
                <th>Title</th>
                <th>Is Root?</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
            { if (false())
                 then <tr><td colspan="4">No maps found</td></tr>
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
      return <tr>
        <td>{bxutil:getPathForDoc($map)}</td>
        <td>{df:getTitleText($map/*)}</td>
        <td>isRoot</td>
        <td>
        [{html:link('Map&#xa0;Tree', concat('/linkmgr/maptreeView/', document-uri($map)))}] 
        [{html:link('Dependencies', concat('/linkmgr/dependencyView/', document-uri($map)))}] 
        [{html:link('Reltables', concat('/linkmgr/reltableView/', document-uri($map)))}] 
        [{html:link('Key&#xa0;Spaces', concat('/linkmgr/keyspaceView/', document-uri($map)))}] 
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
      return <tr>
        <td>{bxutil:getPathForDoc($topic)}</td>
        <td>{df:getTitleText($topic/*)}</td>
        <td>isRoot</td>
        <td>[Action 1][Action 2]</td>
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
