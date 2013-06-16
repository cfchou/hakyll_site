--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Hakyll
import           Data.List (intercalate)
import           System.FilePath (replaceExtension)


--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["about.rst", "contact.markdown"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler -- :: Compiler (Item String)
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    -- create a page per tag
    -- FIXME: must appear before rendering html for Tags. Otherwise <href>
    -- would links to root "/".
    createPagePerTag

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            let archiveCtx =
                    field "posts" (\_ -> postList recentFirst) `mappend`
                    tagsCloudCtx "tags"                   `mappend`
                    constField "title" "Archives"              `mappend`
                    defaultContext

            makeItem "" --  makeItem :: a -> Compiler (Item a)
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            let indexCtx = field "posts" $ \_ ->
                                postList $ fmap (take 3) . recentFirst

            getResourceBody -- :: Compiler (Item String)
                >>= applyAsTemplate indexCtx -- use Item from getResourceBody
                                             -- that gets from index.html
                >>= loadAndApplyTemplate "templates/default.html" postCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

    -- tagsRules :: Tags -> (String -> Pattern -> Rules ()) -> Rules ()
    {--
    ruleTags >>= \tags ->
        tagsRules tags mkRules
    --}


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext


--------------------------------------------------------------------------------
postList :: ([Item String] -> Compiler [Item String]) -> Compiler String
postList sortFilter = do
    posts   <- sortFilter =<< loadAll "posts/*"
    itemTpl <- loadBody "templates/post-item.html"
    list    <- applyTemplateList itemTpl postCtx posts
    return list


--------------------------------------------------------------------------------
-- Compiler and Rules are instances of MonadMetadata
metaTags :: MonadMetadata m => m Tags
metaTags = buildTags "posts/*" mkId
    where 
        mkId = (fromCapture "tags/*.html")
        -- mkId :: String -> Identifier


tagsCloudCtx :: String -> Context String
tagsCloudCtx key = 
    field key $ \_ -> renderTagCloud 100 300 =<< metaTags
    -- field :: String -> (Item a -> Compiler String) -> Context a
 

--
createPagePerTag :: Rules ()
createPagePerTag =
    metaTags >>= \tags ->
        tagsRules tags mkRules -- create ["tags/some_tag.html"]" for each tag

-- Rules for "create ["tags/some_tag.html"]"
mkRules :: String -> Pattern -> Rules ()
mkRules tag pat = do
    route idRoute
    compile $ do
        ids <- getMatches pat   -- "posts/a.md" "posts/b.md"
        let tagPageCtx = 
                field "posts" (\_ -> postListWith pat recentFirst) `mappend`
                constField "title" ("tag: " ++ tag)                `mappend`
                tagsCloudCtx "tags"                           `mappend`
                defaultContext

        makeItem "" --  makeItem :: a -> Compiler (Item a)
            >>= loadAndApplyTemplate "templates/archive.html" tagPageCtx
            >>= loadAndApplyTemplate "templates/default.html" tagPageCtx


postListWith :: Pattern 
             -> ([Item String] -> Compiler [Item String]) 
             -> Compiler String
postListWith pat sortFilter = do
    posts   <- sortFilter =<< loadAll pat
    itemTpl <- loadBody "templates/post-item.html"
    list    <- applyTemplateList itemTpl postCtx posts
    return list
    


tagMembersCtx :: String -> [Identifier] -> Context a
tagMembersCtx s ids = 
    -- field :: String -> (Item a -> Compiler String) -> Context a
    field s $ \_ -> do
        let links = map f ids
        return $ intercalate ", " links
        -- return $ intercalate ", " (map toFilePath ids)
    where
        f id' = replaceExtension (toFilePath id') ".html"
        

--------------------------------------------------------------------------------
