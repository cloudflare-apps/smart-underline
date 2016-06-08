window.SmartUnderline =
  init: ->
  destroy: ->

return unless window['getComputedStyle'] and document.documentElement.getAttribute

PHI = 1.618034

selectionColor = '#b4d5fe'

linkColorAttrName = 'data-smart-underline-link-color'
linkSmallAttrName = 'data-smart-underline-link-small'
linkLargeAttrName = 'data-smart-underline-link-large'
linkAlwysAttrName = 'data-smart-underline-link-always'
linkBgPosAttrName = 'data-smart-underline-link-background-position'
linkHoverAttrName = 'data-smart-underline-link-hover'
containerIdAttrName = 'data-smart-underline-container-id'

performanceTimes = []
time = -> + new Date

linkContainers = {}
uniqueLinkContainerID = do ->
  id = 0
  return -> id += 1

clearCanvas = (canvas, context) ->
  context.clearRect 0, 0, canvas.width, canvas.height

calculateTextHighestY = (text, canvas, context) ->
  clearCanvas canvas, context

  context.fillStyle = 'red'
  textWidth = context.measureText(text).width
  context.fillText text, 0, 0

  highestY = undefined

  for x in [0..textWidth]
    for y in [0..canvas.height]
      pixelData = context.getImageData x, y, x + 1, y + 1

      r = pixelData.data[0]
      alpha = pixelData.data[3]

      if r is 255 and alpha > 50 # TODO - tune this alpha?
        highestY = y if not highestY

        highestY = y if y > highestY

  clearCanvas canvas, context

  highestY

calculateTypeMetrics = (computedStyle) ->
  canvas = document.createElement 'canvas'
  context = canvas.getContext '2d'

  # Ensure that the canvas size is large enough to
  # render the glyphs. 2 * fontSize is sufficient.
  canvas.height = canvas.width = 2 * parseInt computedStyle.fontSize, 10

  context.textBaseline = 'top'
  context.textAlign = 'start'
  context.fontStretch = 1
  context.angle = 0

  # We’d love to use `computedStyle.font` here,
  # but Firefox has issues... (TODO: file bug report)
  context.font = "#{ computedStyle.fontVariant } #{ computedStyle.fontStyle } #{ computedStyle.fontWeight } #{ computedStyle.fontSize }/#{ computedStyle.lineHeight } #{ computedStyle.fontFamily }"

  baselineY = calculateTextHighestY 'I', canvas, context

  gLowestPixel = calculateTextHighestY 'g', canvas, context
  descenderHeight = gLowestPixel - baselineY

  { baselineY, descenderHeight }

calculateBaselineYRatio = (node) ->
  # Roughly taken from underline.js
  # http://git.io/A113
  test = document.createElement 'div'
  test.style.display = 'block'
  test.style.position = 'absolute'
  test.style.bottom = 0
  test.style.right = 0
  test.style.width = 0
  test.style.height = 0
  test.style.margin = 0
  test.style.padding = 0
  test.style.visibility = 'hidden'
  test.style.overflow = 'hidden'
  test.style.wordWrap = 'normal'
  test.style.whiteSpace = 'nowrap'

  small = document.createElement 'span'
  large = document.createElement 'span'

  small.style.display = 'inline'
  large.style.display = 'inline'

  # Large numbers help improve accuracy.
  small.style.fontSize = '0px'
  large.style.fontSize = '2000px'

  small.innerHTML = 'X'
  large.innerHTML = 'X'

  test.appendChild small
  test.appendChild large

  node.appendChild test
  smallRect = small.getBoundingClientRect()
  largeRect = large.getBoundingClientRect()
  node.removeChild test

  # Calculate where the baseline was, percentage-wise.
  baselinePositionY = smallRect.top - largeRect.top
  height = largeRect.height

  baselineYRatio = Math.abs baselinePositionY / height

backgroundPositionYCache = {}

getFirstAvailableFont = (fontFamily) ->
  fonts = fontFamily.split ','

  for font in fonts
    if fontAvailable font
      return font

  return false

fontAvailable = (font) ->
  canvas = document.createElement 'canvas'
  context = canvas.getContext '2d'
  text = 'abcdefghijklmnopqrstuvwxyz0123456789'
  context.font = '72px monospace'
  baselineSize = context.measureText(text).width
  context.font = "72px #{ font }, monospace"
  newSize = context.measureText(text).width
  return false if newSize is baselineSize
  return true

getUnderlineBackgroundPositionY = (node) ->
  computedStyle = getComputedStyle node

  firstAvailableFont = getFirstAvailableFont computedStyle.fontFamily
  if not firstAvailableFont
    cacheKey = "#{ Math.random() }" # AKA, don’t cache
  else
    cacheKey = "font:#{ firstAvailableFont }size:#{ computedStyle.fontSize }weight:#{ computedStyle.fontWeight }"
  cache = backgroundPositionYCache[cacheKey]

  return cache if cache

  { baselineY, descenderHeight } = calculateTypeMetrics computedStyle

  clientRects = node.getClientRects()
  return unless clientRects?.length

  adjustment = 1
  textHeight = clientRects[0].height - adjustment

  # Detect baseline using canvas in all but FF due to
  # https://bugzilla.mozilla.org/show_bug.cgi?id=737852
  # so we use a DOM technique to approximate it
  if -1 < navigator.userAgent.toLowerCase().indexOf 'firefox'
    adjustment = .98
    baselineYRatio = calculateBaselineYRatio node
    baselineY = baselineYRatio * textHeight * adjustment

  descenderY = baselineY + descenderHeight

  fontSizeInt = parseInt computedStyle.fontSize, 10

  minimumCloseness = 3

  backgroundPositionY = baselineY + Math.max minimumCloseness, descenderHeight / PHI

  if descenderHeight is 4
    backgroundPositionY = descenderY - 1

  if descenderHeight is 3
    backgroundPositionY = descenderY

  backgroundPositionYPercent = Math.round 100 * backgroundPositionY / textHeight

  if descenderHeight > 2 and fontSizeInt > 10 and backgroundPositionYPercent <= 100
    backgroundPositionYCache[cacheKey] = backgroundPositionYPercent
    return backgroundPositionYPercent

  return

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

    return count + countParentContainers parentNode

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

isUnderlined = (style) ->
  for property in ['textDecorationLine', 'textDecoration']
    return true if style[property]?.match /\bunderline\b/
  return false

initLink = (link) ->
  style = getComputedStyle link
  fontSize = parseFloat style.fontSize

  if isUnderlined(style) and style.display is 'inline' and fontSize >= 10 and not hasValidLinkContent link
    container = getBackgroundColorNode link

    if container
      backgroundPositionY = getUnderlineBackgroundPositionY link

      if backgroundPositionY
        link.setAttribute linkColorAttrName, getLinkColor link
        link.setAttribute linkBgPosAttrName, backgroundPositionY

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

  linkBackgroundPositionYs = {}

  for container in containersWithPrecedence
    linkColors = {}

    for link in container.links
      linkColors[getLinkColor link] = true
      linkBackgroundPositionYs[getUnderlineBackgroundPositionY link] = true

    backgroundColor = getBackgroundColor container.container

    for color of linkColors
      linkSelector = (modifier = '') -> """
        [#{ containerIdAttrName }="#{ container.id }"] a[#{ linkColorAttrName }="#{ color }"][#{ linkAlwysAttrName }]#{ modifier },
        [#{ containerIdAttrName }="#{ container.id }"] a[#{ linkColorAttrName }="#{ color }"][#{ linkHoverAttrName }]#{ modifier }:hover
      """

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

  for backgroundPositionY of linkBackgroundPositionYs
    styles += """
      a[#{ linkBgPosAttrName }="#{ backgroundPositionY }"] {
        background-position: 0% #{ backgroundPositionY }%, 100% #{ backgroundPositionY }%, 0% #{ backgroundPositionY }%;
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
