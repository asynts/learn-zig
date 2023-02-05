-   Figure out how to connect the language server in Visual Studio Code.

    It seems that the extension targets Zig 0.11.X and not 0.10.X which is installed by Pacman.

### ls

-   Bug: The `.` and `..` entries do not have their permissions listed with `--list`.

### ls-with-yazap

-   Bug: The help page is missing a final newline.

-   Bug: The `Help.getBraces` function crashes the compiler as of `0.10.1`.

### asynts-template

-   Unit test `Lexer`.

-   Parse some HTML syntax at compile time.

-   Consider adding support for XML.

    -   By dropping support for HTML, I could greatly simplify the library.

-   Fix remaining bugs and tweaks:

    -   I don't think we parse `<style>` and `<script` correctly.
        What if there is an unterminated `/*` in there?

        -   We also try to interpret `{` as placeholders which makes no sense.

        -   Maybe I can just allow `<script>{script:trusted}</script>` and nothing else?
            Or I could forbid anything other than `<script src="whatever.js"></script>`.

    -   We do not allow `&quot;` syntax.

-   Remove technical debt:

    -   Add one error enum that is used everywhere.

    -   Add a reasonable amount of documentation.

-   Do a proper security audit in the end.

    -   Beware of parser differentials.

    -   Verify that we are escaping everything that is necessary.

    -   Verify that I did not miss some elements.

    -   Write out a proper grammar and verify it.

    -   Run a fuzzer on it.
