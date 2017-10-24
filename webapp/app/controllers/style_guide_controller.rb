class StyleGuideController < ApplicationController

  def page
    set_pages
    @page = @pages.find{|p| p[:slug] == params[:page_id] }
    render params[:page_id]
  end

  def set_pages
    @pages = [
      { name: "Icons",       slug: "icon"       },
      { name: "Logo",        slug: "logo"       },
      { name: "Typography",  slug: "typography" },
      { name: "Badge",       slug: "badge"      },
      { name: "Button",      slug: "button"     },
      { name: "Dropdown",    slug: "dropdown"   },
      { name: "Form",        slug: "form"       },
      { name: "Table",       slug: "table"      },
      { name: "Card",        slug: "card"       },
      { name: "Blankslate",  slug: "blankslate" },
      { name: "Agent",       slug: "agent"      },
      { name: "Agent box",   slug: "agent_box"  },
      { name: "Modal",       slug: "modal"      },
      { name: "Tabs",        slug: "tabs"       },
      { name: "Nav",         slug: "nav"        }
    ]
  end

end
