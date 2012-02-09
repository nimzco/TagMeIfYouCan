$(document).ready(function() {

    var fillUriInput = function(uri, uriName, wikipediaURL) {
        $(this).find('.query_string').val(uriName);
        $(this).find('.query_string').attr('data-value', uri);
        $(this).find('.tag_wikipedia_url').val(wikipediaURL);
        $(this).find('.results').html('');
    };


    $("#ajax_loader").hide();
    var xhr = $.ajax();
    $(".query_string").keyup(function(event) {
        xhr.abort();
        $("#ajax_loader").hide();
        var val = $(this).val();
        var data = {query_string: val};
        var form_el = $(this).closest('.tag_form');
        if (data.query_string.length > 1) {
            $("#ajax_loader").show();
            xhr = $.ajax({
                url     : "/search",
                type    : "post",
                data    : data,
                dataType: "json",
                success: function(results, b, c) {
                    $("#ajax_loader").hide();   
                    $(form_el).find('.results').empty();
                    _.each(results, function(result){
                        if (result.uri) {
                            uriName = result.uri.value.replace('http://dbpedia.org/resource/', '').replace(/_/g, ' ');
                            uriName = decodeURI(uriName);
                            var liTag = $('<li>' + uriName + '</li>');
                            liTag.click(fillUriInput.bind(form_el, result.uri.value, uriName, result.page.value));
                            $(form_el).find('.results').append(liTag);
                            
                        }
                    });
                }
            });
        } else {
            $(form_el).find('.results').empty();
        }
    });
    
    $('.tag_form').submit(function(){
        $(this).find('.query_string').val($(this).find('.query_string').attr('data-value'));
        $(this).attr('action', $(this).attr('action').replace('__user_id__', $('[name="tag[user_id]"]').val()));
    });
});

// FB.login(function(res){ console.log(res) }, {scope:'friends_about_me'})