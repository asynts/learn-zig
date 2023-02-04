### Notes

-   My code is starting to become a bit messy,

-   ```none
    root =
        input  whitespace? tag_1:tag whitespace?
        output tag_1
        ;

    tag =
        input  tag_1:emptyTag
        output tag_1
        ;
    tag =
        input  tag_1:bodyTag
        output tag_1
        ;

    emptyTag =
        input  '<' id_1:identifier (whitespace attributes:attribute)* whitespace '/>'
        output Tag(.name = id_1, .attributes = [...attributes], .children = [])
        ;

    bodyTag =
        input  '<' id_1:identifier (whitespace attributes:attribute)* '>' (children:bodyString? children:tag)* children:bodyString? '</' id_2:identifier '>'
        output Tag(.name = id_1, .attributes = [...attributes], .children = [...children])
               ComptimeVerify(id_1 == id_2)
        ;

    attribute =
        input  attr_1:flagAttribute
        output attr_1
        ;
    attribute =
        input  attr_1:valueAttribute
        output attr_1
        ;

    flagAttribute =
        input  id_1:identifier
        output Attribute(.name = id_1, .value = null)
        ;

    valueAttribute =
        input  id_1:identifier '="' value_1:stringValue '"'
        output Attribute(.name = id_1, .value = value_1)
        ;

    attributeString =
        input  values:[^"]* (values:placeholder values:[^"]*)
        output String(.values = values, .context = .attribute_value)
        ;

    bodyString =
        input  values:[^<>]* (values:placeholder values:[^<>]*)
        output String(.values = values, .context = .body)
        ;

    placeholder =
        input  '{' id_1:identifier (':' mode_1:('trusted'|'html'))? '}'
        output Placeholder(.name = id_1, .mode = mode_1)
        ;
    ```

### Tasks

-   Verify `*String` vs `whitespace` everywhere.

-   Add all the required `ComptimeVerify` and `RuntimeVerify` statements.

-   Determine the prefixes required to determine what rules apply.
    In the grammar this could be marked with a `$` sign.

    -   After that I can emit `error.UnexpectedCharacter`.

    -   This is only required for rules that have alternatives.
        There are no rules that have an ambigous prefix otherwise.

    -   This may be context dependent based on the rule that activates it?
