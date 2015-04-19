(: =====================================================

   DFST BaseX Utilities
   
   Utilities specific to the DFST use of BaseX for managing
   DITA content.
   
   Author: W. Eliot Kimber
   
   Copyright (c) 2015 DITA For Small Teams
   Licensed under Apache License 2
   

   ===================================================== :)
   
module namespace bxutil="http://dita-for-small-teams.org/xquery/modules/basex-utils";

(:~
 : getGitRepositoryInfos()
 :
 : Returns a list of zero or more <repo> elements, where each <repo>
 : element provides the repository name, branch count, and list of
 : branches in that repository.
 : 
 : This function depends on the DFST BaseX database naming convention
 : of "dfst^{repo}^{branch}
 :
 :
 :)
 declare function bxutil:getGitRepositoryInfos() as element(repo)* {
  (: Organize the databases by repo. BaseX dbs for the same repo will start with the same string :)
  
  let $repos := 
      for $db in db:list-details() order by string($db)  
          let $tokens := tokenize(string($db), '\^')
          return if ($tokens[1] = "dfst")
             then <repo name="{$tokens[2]}" branch="{$tokens[3]}"/>
             else ()
             
   (: Now select repos with the same repository name :)
   return for $name in distinct-values($repos/@name)
       return <repo name="{$name}" branchCount="{count($repos[@name = $name])}">{
              for $branch in $repos[@name = $name]
                  return <branch name="{$branch/@branch}"/>}</repo>
  
 };
 
 (: Constructs the BaseX database name for git repository and branch pair :)
 declare function bxutil:getDbNameForRepoAndBranch($repo, $branch) {
   let $sep := '^'
   return concat('dfst', $sep, $repo, $sep, $branch) 
 };
 
 (: Gets the git repository for a document  :)
 declare function bxutil:getGitRepoForDoc($doc as document-node()) {
    let $uri := document-uri($doc)
    return if (starts-with($uri, 'dfst^'))
       then 
         let $db := tokenize($uri, '/')[1]         
         let $gitMetadata := bxutil:getGitMetadata($db)
         return string($gitMetadata/gitstate/repo)
       else 'No associated git repository'
 };
 
 (: Gets the git repository for a document  :)
 declare function bxutil:getGitBranchForDoc($doc as document-node()) {
    let $uri := document-uri($doc)
    return if (starts-with($uri, 'dfst^'))
       then 
         let $db := tokenize($uri, '/')[1]         
         let $gitMetadata := bxutil:getGitMetadata($db)
         return string($gitMetadata/gitstate/branch)
       else 'No associated git repository'
 };
 
 (: Gets the git repository for a document  :)
 declare function bxutil:getGitCommitForDoc($doc as document-node()) {
    let $uri := document-uri($doc)
    return if (starts-with($uri, 'dfst^'))
       then 
         let $db := tokenize($uri, '/')[1]         
         let $gitMetadata := bxutil:getGitMetadata($db)
         return string($gitMetadata/gitstate/commit)
       else 'No associated git repository'
 };
 
 (: Gets the git metadata document for the database :)
 declare function bxutil:getGitMetadata($db as xs:string) as element(dfst_metadata)? {
   let $uri as xs:string := concat($db, '/dfst/metadata.xml')
   return 
   try {
     doc($uri)/*
   } catch * { 
     () 
   }
    
 };
 
 (: Given a document, returns the path to the doc, omitting the database name :)
 declare function bxutil:getPathForDoc($doc as document-node()) as xs:string {
   bxutil:getPathForDocURI(document-uri($doc))
 };

 declare function bxutil:getPathForDocURI($uri as xs:string) as xs:string {
   string-join(tokenize($uri, '/')[position() gt 1], '/')
 };

(: End of Module :)