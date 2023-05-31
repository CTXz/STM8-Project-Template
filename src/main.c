#include <stm8s.h>
#include <stm8s_it.h>

void main(void)
{
}

// See: https://community.st.com/s/question/0D50X00009XkhigSAB/what-is-the-purpose-of-define-usefullassert
#ifdef USE_FULL_ASSERT
void assert_failed(uint8_t* file, uint32_t line)
{ 
	while (TRUE)
	{
	}
}
#endif