jQuery ($) -> 

    # adds random junk at the end of all ajax get requests to defeat an IE misbehavior
    # where IE refuses to check with the server for fresh content
    $.ajaxSetup cache: false

    $.loading = '<div class="loading"></div>'