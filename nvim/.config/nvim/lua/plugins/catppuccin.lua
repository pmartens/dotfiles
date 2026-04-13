return {
  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    priority = 1000,

    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        auto_integrations = true,
        default_integrations = true,
         transparent_background = false,
      })      
      vim.cmd.colorscheme "catppuccin-nvim"
    end
  }
}