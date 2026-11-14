# .pubflow_error() / prints as an rlang error

    Code
      rlang::cnd_signal(.pubflow_error("pubflow_x", c("Header.", x = "bad", i = "hint"),
      call = quote(pub_fun())))
    Condition
      Error in `pub_fun()`:
      ! Header.
      x bad
      i hint

# .invalid_param_error() / is listed per step and param by pip_set_params()

    Code
      pipeflow::pip_set_params(p, list(alpha = 2, low = "3"))
    Condition
      Error:
      ! Cannot set 2 parameters: nothing was set.
        step 'fit', parameter 'alpha': value must be less than or equal to max (1)
        step 'fit', parameter 'low': must be < high

