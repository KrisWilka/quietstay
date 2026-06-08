import { createSupabaseClient } from '@/lib/supabase';
import { notFound } from 'next/navigation';

export const dynamic = 'force-dynamic';

type Item = {
  id: string;
  title: string | null;
  body: string | null;
  media_url: string | null;
  sensitive: boolean;
  guest_visible: boolean;
  position: number;
};
type Section = {
  id: string;
  title: string;
  icon: string | null;
  position: number;
  items: Item[];
};

export default async function GuidebookPage({ params }: { params: { slug: string } }) {
  const supabase = createSupabaseClient();

  const { data: guidebook } = await supabase
    .from('guidebooks')
    .select(
      'id,title,theme,sections(id,title,icon,position,items(id,title,body,media_url,sensitive,guest_visible,position))'
    )
    .eq('slug', params.slug)
    .eq('status', 'published')
    .single();

  if (!guidebook) return notFound();

  const sections = ((guidebook.sections as Section[]) ?? []).sort(
    (a, b) => a.position - b.position
  );

  return (
    <main className="container">
      <div className="hero">
        <h1>{guidebook.title}</h1>
      </div>

      {sections.map((section) => {
        const items = (section.items ?? [])
          .filter((i) => i.guest_visible)
          .sort((a, b) => a.position - b.position);
        return (
          <div className="section" key={section.id}>
            <h2>{section.title}</h2>
            {items.map((item) => (
              <div className="item" key={item.id}>
                {item.title && (
                  <h3>
                    {item.title}
                    {item.sensitive && <span className="badge">private</span>}
                  </h3>
                )}
                {item.body && <p>{item.body}</p>}
              </div>
            ))}
          </div>
        );
      })}

      <p className="footer">Powered by QuietStay</p>
    </main>
  );
}
