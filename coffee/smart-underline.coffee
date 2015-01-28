window.SmartUnderline =
  init: ->
  destroy: ->

return unless window['getComputedStyle'] and document.documentElement.getAttribute

selectionColor = '#b4d5fe'

linkColorAttrName = 'data-smart-underline-link-color'
linkSmallAttrName = 'data-smart-underline-link-small'
linkLargeAttrName = 'data-smart-underline-link-large'
linkAlwysAttrName = 'data-smart-underline-link-always'
linkHoverAttrName = 'data-smart-underline-link-hover'
containerIdAttrName = 'data-smart-underline-container-id'

performanceTimes = []
time = -> + new Date

linkContainers = {}
uniqueLinkContainerID = do ->
  id = 0
  return -> id += 1

isTransparent = (color) ->
  return true if color in ['transparent', 'rgba(0, 0, 0, 0)']
  rgbaAlphaMatch = color.match /^rgba\(.*,(.+)\)/i

  if rgbaAlphaMatch?.length is 2
    alpha = parseFloat rgbaAlphaMatch[1]

    if alpha < .0001
      return true

  return false

getBackgroundColorNode = (node) ->
  computedStyle = getComputedStyle node
  backgroundColor = computedStyle.backgroundColor

  parentNode = node.parentNode
  reachedRootNode = not parentNode or parentNode is document.documentElement or parentNode is node

  if computedStyle.backgroundImage isnt 'none'
    return null

  if isTransparent backgroundColor
    if reachedRootNode
      return node.parentNode or node

    else
      return getBackgroundColorNode parentNode

  else
    return node

hasValidLinkContent = (node) ->
  # For performance, check for invalid child elements before
  # using getComputedStyle to check for display block elements
  containsInvalidElements(node) or containsAnyNonInlineElements(node)

containsInvalidElements = (node) ->
  for child in node.children
    if child.tagName?.toLowerCase() in ['img', 'video', 'canvas', 'embed', 'object', 'iframe']
      return true

    return containsInvalidElements child

  return false

containsAnyNonInlineElements = (node) ->
  for child in node.children
    style = getComputedStyle child

    if style.display isnt 'inline'
      return true

    return containsAnyNonInlineElements child

  return false

getBackgroundColor = (node) ->
  backgroundColor = getComputedStyle(node).backgroundColor
  if node is document.documentElement and isTransparent backgroundColor
    return 'rgb(255, 255, 255)'
  else
    return backgroundColor

getLinkColor = (node) ->
  getComputedStyle(node).color

styleNode = document.createElement 'style'

countParentContainers = (node, count = 0) ->
  parentNode = node.parentNode
  reachedRootNode = not parentNode or parentNode is document or parentNode is node

  if reachedRootNode
    return count

  else
    if parentNode.hasAttribute containerIdAttrName
      count += 1

    return count + countParentContainers(parentNode)

sortContainersForCSSPrecendence = (containers) ->
  sorted = []

  for id, container of containers
    container.depth = countParentContainers container.container
    sorted.push container

  sorted.sort (a, b) ->
    return -1 if a.depth < b.depth
    return 1 if a.depth > b.depth
    return 0

  return sorted

initLink = (link) ->
  style = getComputedStyle link
  fontSize = parseFloat style.fontSize

  if style.textDecoration is 'underline' and style.display is 'inline' and fontSize >= 8 and not hasValidLinkContent(link)
    container = getBackgroundColorNode link

    if container
      link.setAttribute linkColorAttrName, getLinkColor(link)

      if fontSize <= 14
        link.setAttribute linkSmallAttrName, ''

      if fontSize >= 20
        link.setAttribute linkLargeAttrName, ''

      id = container.getAttribute containerIdAttrName

      if id
        linkContainers[id].links.push link
      else
        id = uniqueLinkContainerID()
        container.setAttribute containerIdAttrName, id
        linkContainers[id] =
          id: id
          container: container
          links: [link]

      return true

  return false

renderStyles = ->
  styles = ''

  containersWithPrecedence = sortContainersForCSSPrecendence linkContainers

  for container in containersWithPrecedence
    linkColors = {}
    linkColors[getLinkColor link] = true for link in container.links

    backgroundColor = getBackgroundColor container.container

    for color of linkColors
      linkSelector = (modifier = '') -> """
        [#{ containerIdAttrName }="#{ container.id }"] a[#{ linkColorAttrName }="#{ color }"][#{ linkAlwysAttrName }]#{ modifier },
        [#{ containerIdAttrName }="#{ container.id }"] a[#{ linkColorAttrName }="#{ color }"][#{ linkHoverAttrName }]#{ modifier }:hover
      """
      linkSmallSelector = linkSelector linkSmallAttrName
      linkLargeSelector = linkSelector linkLargeAttrName

      styles += """
        #{ linkSelector() }, #{ linkSelector ':visited' } {
          color: #{ color };
          text-decoration: none !important;
          text-shadow: 0.03em 0 #{ backgroundColor }, -0.03em 0 #{ backgroundColor }, 0 0.03em #{ backgroundColor }, 0 -0.03em #{ backgroundColor }, 0.06em 0 #{ backgroundColor }, -0.06em 0 #{ backgroundColor }, 0.09em 0 #{ backgroundColor }, -0.09em 0 #{ backgroundColor }, 0.12em 0 #{ backgroundColor }, -0.12em 0 #{ backgroundColor }, 0.15em 0 #{ backgroundColor }, -0.15em 0 #{ backgroundColor };
          background-color: transparent;
          background-image: -webkit-linear-gradient(#{ backgroundColor }, #{ backgroundColor }), -webkit-linear-gradient(#{ backgroundColor }, #{ backgroundColor }), -webkit-linear-gradient(#{ color }, #{ color });
          background-image: -moz-linear-gradient(#{ backgroundColor }, #{ backgroundColor }), -moz-linear-gradient(#{ backgroundColor }, #{ backgroundColor }), -moz-linear-gradient(#{ color }, #{ color });
          background-image: -o-linear-gradient(#{ backgroundColor }, #{ backgroundColor }), -o-linear-gradient(#{ backgroundColor }, #{ backgroundColor }), -o-linear-gradient(#{ color }, #{ color });
          background-image: -ms-linear-gradient(#{ backgroundColor }, #{ backgroundColor }), -ms-linear-gradient(#{ backgroundColor }, #{ backgroundColor }), -ms-linear-gradient(#{ color }, #{ color });
          background-image: linear-gradient(#{ backgroundColor }, #{ backgroundColor }), linear-gradient(#{ backgroundColor }, #{ backgroundColor }), linear-gradient(#{ color }, #{ color });
          -webkit-background-size: 0.05em 1px, 0.05em 1px, 1px 1px;
          -moz-background-size: 0.05em 1px, 0.05em 1px, 1px 1px;
          background-size: 0.05em 1px, 0.05em 1px, 1px 1px;
          background-repeat: no-repeat, no-repeat, repeat-x;
          background-position: 0% 89%, 100% 89%, 0% 89%;
        }

        #{ linkSelector "[#{ linkSmallAttrName }]" } {
          background-position: 0% 96%, 100% 96%, 0% 96%;
        }

        #{ linkSelector "[#{ linkLargeAttrName }]" } {
          background-position: 0% 86%, 100% 86%, 0% 86%;
        }

        #{ linkSelector '::selection' } {
          text-shadow: 0.03em 0 #{ selectionColor }, -0.03em 0 #{ selectionColor }, 0 0.03em #{ selectionColor }, 0 -0.03em #{ selectionColor }, 0.06em 0 #{ selectionColor }, -0.06em 0 #{ selectionColor }, 0.09em 0 #{ selectionColor }, -0.09em 0 #{ selectionColor }, 0.12em 0 #{ selectionColor }, -0.12em 0 #{ selectionColor }, 0.15em 0 #{ selectionColor }, -0.15em 0 #{ selectionColor };
          background: #{ selectionColor };
        }

        #{ linkSelector '::-moz-selection' } {
          text-shadow: 0.03em 0 #{ selectionColor }, -0.03em 0 #{ selectionColor }, 0 0.03em #{ selectionColor }, 0 -0.03em #{ selectionColor }, 0.06em 0 #{ selectionColor }, -0.06em 0 #{ selectionColor }, 0.09em 0 #{ selectionColor }, -0.09em 0 #{ selectionColor }, 0.12em 0 #{ selectionColor }, -0.12em 0 #{ selectionColor }, 0.15em 0 #{ selectionColor }, -0.15em 0 #{ selectionColor };
          background: #{ selectionColor };
        }
      """

  styleNode.innerHTML = styles

initLinkOnHover = ->
  link = @

  alreadyMadeSmart = link.hasAttribute linkHoverAttrName

  unless alreadyMadeSmart
    madeSmart = initLink link

    if madeSmart
      link.setAttribute linkHoverAttrName, ''

      renderStyles()

init = (options) ->
  startTime = time()

  links = document.querySelectorAll "#{ if options.location then options.location + ' ' else '' }a"
  return unless links.length

  linkContainers = {}
  for link in links
    madeSmart = initLink link

    if madeSmart
      link.setAttribute linkAlwysAttrName, ''

    else
      link.removeEventListener 'mouseover', initLinkOnHover
      link.addEventListener 'mouseover', initLinkOnHover

  renderStyles()

  document.body.appendChild styleNode

  performanceTimes.push time() - startTime

destroy = ->
  styleNode.parentNode?.removeChild styleNode

  Array::forEach.call document.querySelectorAll("[#{ linkHoverAttrName }]"), (node) ->
    node.removeEventListener initLinkOnHover

  for attribute in [linkColorAttrName, linkSmallAttrName, linkLargeAttrName, linkAlwysAttrName, linkHoverAttrName, containerIdAttrName]
    Array::forEach.call document.querySelectorAll("[#{ attribute }]"), (node) ->
      node.removeAttribute attribute

window.SmartUnderline =
  init: (options = {}) ->
    if document.readyState is 'loading'
      window.addEventListener 'DOMContentLoaded', ->
        init options

      window.addEventListener 'load', ->
        destroy()
        init options

    else
      destroy()
      init options

  destroy: ->
    destroy()

  performanceTimes: ->
    performanceTimes
