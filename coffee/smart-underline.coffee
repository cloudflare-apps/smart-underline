window.SmartUnderline =
  init: ->
  destroy: ->

return unless window['getComputedStyle'] and document.documentElement.getAttribute

selectionColor = '#b4d5fe'
linkColorDataAttributeName = 'data-smart-underline-link-color'
linkSmallDataAttributeName = 'data-smart-underline-link-small'
linkLargeDataAttributeName = 'data-smart-underline-link-large'
linkContainerIdDataAttributeName = 'data-smart-underline-container-id'
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

getBackgroundColor = (node) ->
  backgroundColor = getComputedStyle(node).backgroundColor
  if node is document.documentElement and isTransparent backgroundColor
    return 'rgb(255, 255, 255)'
  else
    return backgroundColor

getLinkColor = (node) ->
  getComputedStyle(node).color

styleEl = document.createElement 'style'

init = (options) ->
  links = document.querySelectorAll "#{ if options.location then options.location + ' ' else '' }a"
  return unless links.length

  linkContainers = {}
  for link in links
    style = getComputedStyle link
    fontSize = parseFloat style.fontSize
    if style.textDecoration is 'underline' and style.display is 'inline' and fontSize >= 8
      container = getBackgroundColorNode link

      if container
        link.setAttribute linkColorDataAttributeName, getLinkColor(link)

        if fontSize <= 14
          link.setAttribute linkSmallDataAttributeName, ''

        if fontSize >= 20
          link.setAttribute linkLargeDataAttributeName, ''

        id = container.getAttribute linkContainerIdDataAttributeName

        if id
          linkContainers[id].links.push link
        else
          id = uniqueLinkContainerID()
          container.setAttribute linkContainerIdDataAttributeName, id
          linkContainers[id] =
            container: container
            links: [link]

  styles = ''

  for id, container of linkContainers
    linkColors = {}
    linkColors[getLinkColor link] = true for link in container.links

    backgroundColor = getBackgroundColor container.container

    for color of linkColors
      linkSelector = """[#{ linkContainerIdDataAttributeName }="#{ id }"] a[#{ linkColorDataAttributeName }="#{ color }"]"""
      linkSmallSelector = """#{ linkSelector }[#{ linkSmallDataAttributeName }]"""
      linkLargeSelector = """#{ linkSelector }[#{ linkLargeDataAttributeName }]"""

      styles += """
        #{ linkSelector }, #{ linkSelector }:visited {
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
          background-position: 0% 90%, 100% 90%, 0% 90%;
        }

        #{ linkSmallSelector } {
          background-position: 0% 96%, 100% 96%, 0% 96%;
        }

        #{ linkLargeSelector } {
          background-position: 0% 87%, 100% 87%, 0% 87%;
        }

        #{ linkSelector }::selection {
          text-shadow: 0.03em 0 #{ selectionColor }, -0.03em 0 #{ selectionColor }, 0 0.03em #{ selectionColor }, 0 -0.03em #{ selectionColor }, 0.06em 0 #{ selectionColor }, -0.06em 0 #{ selectionColor }, 0.09em 0 #{ selectionColor }, -0.09em 0 #{ selectionColor }, 0.12em 0 #{ selectionColor }, -0.12em 0 #{ selectionColor }, 0.15em 0 #{ selectionColor }, -0.15em 0 #{ selectionColor };
          background: #{ selectionColor };
        }

        #{ linkSelector }::-moz-selection {
          text-shadow: 0.03em 0 #{ selectionColor }, -0.03em 0 #{ selectionColor }, 0 0.03em #{ selectionColor }, 0 -0.03em #{ selectionColor }, 0.06em 0 #{ selectionColor }, -0.06em 0 #{ selectionColor }, 0.09em 0 #{ selectionColor }, -0.09em 0 #{ selectionColor }, 0.12em 0 #{ selectionColor }, -0.12em 0 #{ selectionColor }, 0.15em 0 #{ selectionColor }, -0.15em 0 #{ selectionColor };
          background: #{ selectionColor };
        }
      """

  styleEl.innerHTML = styles
  document.body.appendChild styleEl

window.SmartUnderline =
  init: (options = {}) ->
    if document.readyState is 'loading'
      window.addEventListener 'DOMContentLoaded', init.bind(null, options)
    else
      init options

  destroy: ->
    styleEl.parentNode?.removeChild styleEl
