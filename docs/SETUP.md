# INSTALLATION

For stable versions, use this

```
haxelib install hscript-gscript
```

For unstable versions however, use this

```
haxelib git hscript-gscript https://github.com/brainy/hscript-gscript/
```

Once this is done, go to your Project File, whether that be a build.hxml for Haxe Projects, or Project.xml for OpenFL and Flixel projects, and add `hscript-gscript` to your libraries

---

# SETUP IN HAXE PROJECTS

### Haxe Project Example
```hxml
--library hscript-gscript
# this is optional and can be added if wanted
# provides descriptive traces and better error handling at runtime
-D hscriptPos
```

### OpenFL / Flixel Project Example

```xml
<haxelib name="hscript-gscript"/>
<haxedef name="hscriptPos"/>
```