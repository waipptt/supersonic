###
 # @namespace components
 # @name super-navbar
 # @component
 # @description
 # Displays a view-specific native navigation bar. To set a title text and buttons for the navigation bar, use the `<super-navbar-title>` and `<super-navbar-button>` components.
 # @exampleHtml
 # <!-- Navbar with a title -->
 # <super-navbar>
 #
 #   <super-navbar-title>I'm native!</super-navbar-title>
 #
 # </super-navbar>
###


# (Element, [attributeName]) -> Bacon.Property attributes
observeAttributesOnElement = (element, attributes) ->
  supersonic.internal.Bacon.fromBinder((sink) ->
    # Set up MutationObserver for streaming changes
    observer = new MutationObserver (mutations) ->
      changes = {}
      # Collect changes from tracked attributes
      for mutation in mutations when (mutation.type is "attributes") and (mutation.attributeName in attributes)
        changes[mutation.attributeName] = mutation.target.getAttribute(mutation.attributeName) || ""
      sink changes

    # Start observing changes in the tracked attributes
    observer.observe element, {
      attributes: true
      attributeFilter: attributes
    }

    # Stop listening by disconnecting the observer
    ->
      observer.disconnect()
  ).toProperty(do ->
    # Make sure there's an initial value
    initial = {}
    for attributeName in attributes
      initial[attributeName] = element.getAttribute(attributeName) || ""
    initial
  )

document.registerElement "super-navbar", class SuperNavbar extends HTMLElement
  _leftButtons: null
  _leftButtons: null
  _propertiesChanged: null
  _properties: null

  getButtons: ->
    {
      left: @_leftButtons
      right: @_rightButtons
    }

  isHidden: ->
    style = window.getComputedStyle this
    return true if style.display is "none" or style.visibility is "hidden"

  # Methods for navbar buttons

  addButton: (button, side="left") ->
    # Figure out the side where to add button
    if side is "right" then @_rightButtons.push button
    else @_leftButtons.push button
    # Update buttons on UI
    @onButtonsChanged()

  updateButton: (button) ->
    # First check the left side for the button reference
    for candidate, idx in @_leftButtons when candidate is button
      @_leftButtons[idx] = button
      @onButtonsChanged()
      return
    # Check right side for the reference
    for candidate, idx in @_rightButtons when candidate is button
      @_rightButtons[idx] = button
      @onButtonsChanged()
      return

  changeButtonSide: (button, side="left") ->
    @_removeButtonSilently button
    @addButton button, side

  removeButton: (button) ->
    @_removeButtonSilently button
    @onButtonsChanged()

  _removeButtonSilently: (button) ->
    # First check the left side for the button reference
    for candidate, idx in @_leftButtons when candidate is button
      @_leftButtons.splice idx, 1
      return
    # Check right side for the reference
    for candidate, idx in @_rightButtons when candidate is button
      @_rightButtons.splice idx, 1
      return

  onButtonsChanged: ->
    @_propertiesChanged.push "buttons"

  setTitle: (title) ->
    @_properties.title = title
    @_propertiesChanged.push "title"

  attachedCallback: ->
    # Initialize object state. The regular constructor does not get run.
    @_properties = {}
    @_leftButtons = []
    @_rightButtons = []
    @_propertiesChanged = new supersonic.internal.Bacon.Bus

    # Listen for changes in attributes and write the changes to properties
    @_unsubscribeFromAttributeChanges = observeAttributesOnElement(
        this
        ["style", "class", "id"]
      )
      .onValue (attributes) =>
        for key, value of attributes
          @_properties[key] = value
          @_propertiesChanged.push key

    # TODO: We would like to render if we are in a tab but invisible, but not when we're in a preloaded view.
    # The current behavior is to defer rendering until we become visible, even if in a tab.

    # Listen for changes in renderable properties
    @_unsubscribeFromPropertyChanges =
      # Only trigger renders when visible
      supersonic.ui.views.current.visibility.flatMapLatest((visible) =>
        if visible
          @_propertiesChanged.startWith('all')
        else
          supersonic.internal.Bacon.never()
      )
      # Wait for 20ms to accumulate new changes before rerender
      .bufferWithTime(20)
      # Hide the bar if it has become hidden or render and show
      .onValue (changed) =>
        if @isHidden()
          supersonic.ui.navigationBar.hide()
        else
          supersonic.ui.navigationBar.setClass @_properties.class || ""
          supersonic.ui.navigationBar.setStyle @_properties.style || ""
          supersonic.ui.navigationBar.setStyleId @_properties.id || ""
          supersonic.ui.navigationBar.update {
            title: @_properties.title || " "
            buttons: @getButtons()
          }
          supersonic.ui.navigationBar.show()

  detachedCallback: ->
    @_unsubscribeFromAttributeChanges()
    @_unsubscribeFromPropertyChanges()
    # Hide the navbar when this node leaves the DOM
    supersonic.ui.navigationBar.hide()
