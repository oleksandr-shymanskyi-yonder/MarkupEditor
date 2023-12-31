MU.addDiv = function(id, parentId, cssClass, jsonAttributes, htmlContents) {
    const parent = document.getElementById(parentId);
    if (!parent) {
        _consoleLog("Cannot find parent " + parentId + " to add div " + id);
        return
    }
    const div = document.createElement('div');
    div.setAttribute('id', id);
    div.setAttribute('class', cssClass);
    if (jsonAttributes) {
        const editableAttributes = JSON.parse(jsonAttributes);
        if (editableAttributes) {
            _setAttributes(div, editableAttributes);
        };
    };
    if (htmlContents) {
        const template = document.createElement('template');
        template.innerHTML = htmlContents;
        const newElement = template.content;
        div.appendChild(newElement);
    };
    parent.appendChild(div);
};

MU.addButton = function(id, cssClass, label, divId) {
    const button = document.createElement('button');
    button.setAttribute('id', id);
    button.setAttribute('class', cssClass);
    button.setAttribute('type', 'button');
    button.appendChild(document.createTextNode(label));
    button.addEventListener('click', function() {
        _callback(
            JSON.stringify({
                'messageType' : 'buttonClicked',
                'id' : id,
                'rect' : _getButtonRect(button)
            })
        )
    });
    const div = document.getElementById(divId);
    if (div) {
        div.appendChild(button);
    } else {
        MU.editor.appendChild(button);
    }
};

const _getButtonRect = function(button) {
    const boundingRect = button.getBoundingClientRect();
    const buttonRect = {
        'x' : boundingRect.left,
        'y' : boundingRect.top,
        'width' : boundingRect.width,
        'height' : boundingRect.height
    };
    return buttonRect;
};
