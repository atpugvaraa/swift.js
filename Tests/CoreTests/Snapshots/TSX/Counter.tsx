'use client';
import { useState } from 'react';

import { Button, Text, VStack } from '@swiftuijs/ui';

export const Counter = () => {
  const [count, setCount] = useState(0);

  return (
    <VStack>
<Text>
{`Count is ${count}`}
</Text>
<Button style={{ padding: 16 }} onClick={() => {
    setCount(count + 1);
}}>
{"Increment"}
</Button>
</VStack>
  );
}
