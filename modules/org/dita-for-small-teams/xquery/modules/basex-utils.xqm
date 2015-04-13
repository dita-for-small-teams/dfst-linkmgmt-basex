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

(: End of Module :)